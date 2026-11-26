// SPDX-License-Identifier: AGPL-3.0-only
// Tahow compositor material. Uses Hyprland's native acrylic provider (BSD-3-Clause).
#include <cerrno>
#include <cmath>
#include <dlfcn.h>
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/view/LayerSurface.hpp>
#include <hyprland/src/desktop/view/window/WindowBackend.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/render/GLRenderer.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/Shader.hpp>
#include <hyprland/src/render/gl/blur/Acrylic.hpp>
#include <hyprland/src/state/MonitorState.hpp>
#include <map>
#include <memory>
#include <regex>
#include <nlohmann/json.hpp>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>
#include <wayland-server-core.h>

using json = nlohmann::json;
using namespace Render;
namespace {
HANDLE handle;
CFunctionHook *addHook = nullptr;
CFunctionHook *renderHook = nullptr;
CFunctionHook *expandHook = nullptr;
CFunctionHook *shaderHook = nullptr;
bool drawingNativeMaterial = false;
// Private programs only: the host's shader cache and other acrylic users retain
// the original material. Variants are bounded by the compositor's own keys.
std::map<SShaderVariant, SP<CShader>> materialShaders;
std::map<CRenderPass *, size_t> nativePassCounts;
size_t nativeDamageDepth = 0;
using RenderPass = CRegion (*)(CRenderPass *, CRenderContext &, const CRegion &);
using ExpandDamage = void (*)(const GL::CHyprGLRenderer *, CRegion &, float);
using Add = void (*)(CRenderPass *, UP<IPassElement> &&);
struct Optics {
    float refraction = 24, bulb = 14, clarity = 0.7, aberration = 0.08, innerShadow = 1, rim = 1, prism = 0;
};
Optics currentOptics;
using ShaderVariant = WP<CShader> (*)(GL::CHyprOpenGLImpl *, ePreparedFragmentShader, const SShaderVariant &);
WP<CShader> materialShader(GL::CHyprOpenGLImpl *backend, ePreparedFragmentShader fragment, const SShaderVariant &variant) {
    if (!drawingNativeMaterial || fragment != SH_FRAG_ACRYLICFINISH)
        return reinterpret_cast<ShaderVariant>(shaderHook->m_original)(backend, fragment, variant);
    auto &shader = materialShaders[variant];
    if (!shader) {
        auto source = g_pShaderLoader->getVariantSource(fragment, variant);
        const std::regex shadow(R"(acrylicLinear\s*\*=\s*1\.0\s*-\s*shadow\s*;)");
        if (!std::regex_search(source, shadow))
            throw std::runtime_error("Tahow: unsupported acrylic inner-shadow shader; rebuild required");
        source = std::regex_replace(source, shadow, "acrylicLinear *= 1.0 - shadow * tahowInnerShadow;");
        const std::regex highlight(R"(float highlight = outerRim[^;]*;[\s\S]*?highlight \*= effect[^;]*;)");
        if (!std::regex_search(source, highlight))
            throw std::runtime_error("Tahow: unsupported acrylic rim shader; rebuild required");
        source = std::regex_replace(source, highlight, R"(float highlight = exp(-opticalDepth / 0.85) * (0.06 + 0.36 * max(directional, 0.0));
    highlight += exp(-opticalDepth / 1.6) * 0.16 * max(-directional, 0.0);
    highlight *= effect * tahowRim * mix(0.55, 0.32, normalizedLuma);)");
        source = std::regex_replace(source, std::regex(R"(vec4\s+applyAcrylic\s*\()"), "uniform highp float tahowInnerShadow;\nuniform highp float tahowRim;\nvec4 applyAcrylic(");
        const std::string bulbWidth = "float bulbWidth = clamp(acrylicBulb, 1.0, maximumBulb);";
        const std::string lens = "float lens = lensEntry * lensExit;";
        const std::string travelDirection = "float availableTravel = availableTextureTravel(v_texcoord, outwardUV, halfTexel, maximumUV);";
        const std::string displacement = "vec2 displacementPixels = outward * safeRefraction * lens * effect;";
        const std::string channels = "vec2 redUV = clamp(v_texcoord + displacementUV, halfTexel, maximumUV);\n    vec2 greenUV = clamp(v_texcoord + displacementUV * (1.0 - aberration * 0.5), halfTexel, maximumUV);\n    vec2 blueUV = clamp(v_texcoord + displacementUV * (1.0 - aberration), halfTexel, maximumUV);";
        const std::string clarity = "float clarity = clamp(acrylicClarity, 0.0, 1.0) * effect * fresnelTransmission * clarityCore;";
        if (source.find(bulbWidth) == std::string::npos || source.find(lens) == std::string::npos || source.find(travelDirection) == std::string::npos ||
            source.find(displacement) == std::string::npos || source.find(channels) == std::string::npos || source.find(clarity) == std::string::npos)
            throw std::runtime_error("Tahow: unsupported acrylic lens shader; rebuild required");
        source.replace(source.find(bulbWidth), bulbWidth.size(), "float bulbWidth = mix(clamp(acrylicBulb, 1.0, max(minimumHalfSize, 1.0)), clamp(acrylicBulb, maximumBulb, max(minimumHalfSize, 1.0)), tahowPrism);");
        source.replace(source.find(lens), lens.size(), "float lens = mix(1.0 - progress, lensEntry * (1.0 - smootherstep(0.35, 1.0, progress)), tahowPrism);");
        source.replace(source.find(travelDirection), travelDirection.size(), "float availableTravel = availableTextureTravel(v_texcoord, outwardUV * mix(-1.0, 1.0, tahowPrism), halfTexel, maximumUV);");
        // Bound the slope of the inward lens so it cannot fold and repeat the backdrop.
        source.replace(source.find(displacement), displacement.size(), "float travel = mix(min(safeRefraction, 0.94 * bulbWidth) * lens, min(safeRefraction, 0.68 * bulbWidth) * progress * (1.0 - smootherstep(0.55, 1.0, progress)), tahowPrism);\n    vec2 displacementPixels = outward * travel * effect * mix(-1.0, 1.0, tahowPrism);");
        source.replace(source.find(channels), channels.size(), R"(
    float spread = aberration * mix(1.0, 3.6, tahowPrism);
    vec2 redUV = clamp(v_texcoord + displacementUV * (1.0 + spread), halfTexel, maximumUV);
    vec2 greenUV = clamp(v_texcoord + displacementUV * 1.0, halfTexel, maximumUV);
    vec2 blueUV = clamp(v_texcoord + displacementUV * (1.0 - spread), halfTexel, maximumUV);)");
        source.replace(source.find(clarity), clarity.size(), "float clarity = effect * mix(max(0.82 * acrylicClarity * clarityCore, lens), acrylicClarity, tahowPrism);");
        source = std::regex_replace(source, std::regex(R"(vec4\s+applyAcrylic\s*\()"), "uniform highp float tahowPrism;\nvec4 applyAcrylic(");
        auto program = makeShared<CShader>();
        const auto &vertex = source.find("#version 320") != std::string::npos ? backend->m_shaders->TEXVERTSRC320 : backend->m_shaders->TEXVERTSRC;
        if (!program->createProgram(vertex, source))
            throw std::runtime_error("Tahow: inner-shadow shader compilation failed");
        shader = program;
    }
    return shader;
}
class Material final : public GL::IGLBlurMaterial {
    GL::CAcrylicBlurMaterial native;

  public:
    eBlurType type() const noexcept override { return eBlurType::BLUR_ACRYLIC; }
    GL::SBlurMaterialRequirements requirements() const noexcept override { return native.requirements(); }
    float sampleRadius() const override { return 49.F; }
    void bindFinish(CRenderContext &ctx, WP<CShader> shader, const GL::SBlurMaterialContext &context) const override {
        native.bindFinish(ctx, shader, context);
        shader->setUniformFloat(SHADER_ACRYLIC_REFRACTION, currentOptics.refraction);
        shader->setUniformFloat(SHADER_ACRYLIC_BULB, currentOptics.bulb);
        shader->setUniformFloat(SHADER_ACRYLIC_CLARITY, currentOptics.clarity);
        shader->setUniformFloat(SHADER_ACRYLIC_ABERRATION, currentOptics.aberration);
        shader->setUniformFloat4(SHADER_ACRYLIC_TINT, 0, 0, 0, 0);
        glUniform1f(glGetUniformLocation(shader->program(), "tahowInnerShadow"), currentOptics.innerShadow);
        glUniform1f(glGetUniformLocation(shader->program(), "tahowRim"), currentOptics.rim);
        glUniform1f(glGetUniformLocation(shader->program(), "tahowPrism"), currentOptics.prism);
    }
};
std::unique_ptr<GL::CDualKawaseBlurProvider> provider;
int listener = -1;
wl_event_source *listenerSource = nullptr;
std::string socketPath;
bool socketOwned = false;
struct Region {
    CBox box;
    CBox clip;
    double radius = 20, alpha = 1;
    std::string target, screen;
    Optics optics;
    bool presented = false;
    bool surfaceLocal = false;
    pid_t pid = -1;
};
struct Client {
    int fd;
    pid_t pid;
    wl_event_source *source = nullptr;
    std::string input;
    std::map<std::string, Region> regions;
};
std::map<int, std::unique_ptr<Client>> clients;
uint64_t frames = 0;

void reply(Client &c, const json &msg) {
    const auto data = msg.dump() + "\n";
    // Status messages are small; never block the compositor for a slow consumer.
    send(c.fd, data.data(), data.size(), MSG_DONTWAIT | MSG_NOSIGNAL);
}
void damage(const Region &r) {
    if (!r.surfaceLocal) { g_pHyprRenderer->damageBox(r.box); return; }
    if (r.target == "quickshell:tahow-input") {
        for (const auto &monitor : State::monitorState()->monitors()) {
            if (!r.screen.empty() && monitor->m_name != r.screen) continue;
            for (const auto &layers : monitor->m_layerSurfaceLayers) {
                for (const auto &ref : layers) {
                    const auto layer = ref.lock();
                    if (!layer || layer->m_namespace != r.target || layer->getPID() != r.pid) continue;
                    const auto base = layer->geometricBox(Desktop::View::IGeometric::GEOMETRIC_CURRENT);
                    auto box = r.box;
                    box.translate(Vector2D{base.x, base.y});
                    g_pHyprRenderer->damageBox(box);
                }
            }
        }
        return;
    }
    // Wayland clients do not know a toplevel's global position. Resolve the
    // authenticated owner's real geometry inside the compositor instead.
    for (const auto &window : Desktop::windowState()->windows()) {
        if (window->metadata().title() != "Tahow Preferences" || window->backend().pid() != r.pid) continue;
        auto box = r.box;
        const auto base = window->geometricBox(Desktop::View::IGeometric::GEOMETRIC_CURRENT);
        box.translate(Vector2D{base.x, base.y});
        g_pHyprRenderer->damageBox(box);
    }
}
void closeClient(int fd) {
    auto it = clients.find(fd);
    if (it == clients.end())
        return;
    for (auto &[id, r] : it->second->regions)
        damage(r);
    if (it->second->source)
        wl_event_source_remove(it->second->source);
    close(fd);
    clients.erase(it);
}
bool allowed(const std::string &s) {
    return s == "quickshell:island" || s == "launcher-noblur" || s == "ryoku-widgets" || s == "tahow-live-test" || s == "tahow-settings" || s == "quickshell:tahow-input";
}
void message(Client &c, const json &j) {
    const auto op = j.value("op", std::string());
    if (op == "hello") {
        reply(c, {{"op", "hello"}, {"version", 1}, {"provider", "hyprland-acrylic"}, {"prism", true}, {"inputPanel", true}});
        return;
    }
    if (op == "stats") {
        reply(c, {{"op", "stats"}, {"frames", frames}, {"clients", clients.size()}, {"regions", c.regions.size()}});
        return;
    }
    const auto id = j.value("id", std::string());
    if (id.empty() || id.size() > 80)
        return;
    auto old = c.regions.find(id);
    if (op == "remove") {
        if (old != c.regions.end()) {
            damage(old->second);
            c.regions.erase(old);
        }
        return;
    }
    if (op != "region" || (old == c.regions.end() && c.regions.size() >= 32))
        return;
    Region r;
    r.pid = c.pid;
    r.target = j.at("target").get<std::string>();
    r.screen = j.value("screen", std::string());
    if (!allowed(r.target) || r.screen.size() > 128)
        return;
    r.surfaceLocal = j.value("surfaceLocal", false);
    if (r.surfaceLocal && r.target != "tahow-settings" && r.target != "quickshell:tahow-input") return;
    const double x = j.at("x"), y = j.at("y"), w = j.at("width"), h = j.at("height");
    r.radius = j.at("radius");
    r.alpha = j.at("alpha");
    const double depth = j.value("thickness", 24.), ior = j.value("ior", 1.5), bezel = j.value("bezel", 14.), frost = j.value("frost", 8.),
                 dispersion = j.value("dispersion", 0.08), innerShadow = j.value("innerShadow", 1.), rim = j.value("rim", 1.);
    for (double v : {depth, ior, bezel, frost, dispersion, innerShadow, rim})
        if (!std::isfinite(v))
            return;
    const bool prism = j.value("prism", false);
    r.optics = {static_cast<float>(std::clamp(prism ? std::max(depth * (ior - 1) * 2.5, 38.) : depth * (ior - 1) * 9.0, 0., 48.)), static_cast<float>(std::clamp(bezel * (prism ? 4.0 : 2.0), 1., 256.)),
                static_cast<float>(prism ? 1. : 1 - std::clamp(frost / 30., 0., 1.)), static_cast<float>(std::clamp(prism ? std::max(dispersion * 2., 0.18) : dispersion, 0., 0.25)),
                static_cast<float>(std::clamp(innerShadow, 0., 1.)), static_cast<float>(std::clamp(rim, 0., 1.)), prism ? 1.F : 0.F};
    for (double v : {x, y, w, h, r.radius, r.alpha})
        if (!std::isfinite(v))
            return;
    if (std::abs(x) > 65536 || std::abs(y) > 65536 || w < 1 || h < 1 || w > 16384 || h > 16384)
        return;
    r.box = CBox{x, y, w, h};
    const double clipX = j.value("clipX", x), clipY = j.value("clipY", y), clipWidth = j.value("clipWidth", w),
                 clipHeight = j.value("clipHeight", h);
    for (double v : {clipX, clipY, clipWidth, clipHeight})
        if (!std::isfinite(v))
            return;
    if (std::abs(clipX) > 65536 || std::abs(clipY) > 65536 || clipWidth < 0 || clipHeight < 0 || clipWidth > 16384 || clipHeight > 16384)
        return;
    r.clip = CBox{clipX, clipY, clipWidth, clipHeight}.intersection(r.box);
    r.radius = std::clamp(r.radius, 0., std::min(w, h) / 2.);
    r.alpha = std::clamp(r.alpha, 0., 1.);
    if (old != c.regions.end()) {
        r.presented = old->second.presented;
        damage(old->second);
    }
    c.regions[id] = r;
    damage(r);
}
int readClient(int fd, uint32_t mask, void *) {
    if (mask & (WL_EVENT_HANGUP | WL_EVENT_ERROR)) {
        closeClient(fd);
        return 0;
    }
    auto it = clients.find(fd);
    if (it == clients.end())
        return 0;
    auto &c = *it->second;
    char buffer[4096];
    // Bound work per dispatch so an abusive peer cannot starve rendering.
    for (int count = 0; count < 16; count++) {
        auto n = recv(fd, buffer, sizeof(buffer), MSG_DONTWAIT);
        if (n == 0) {
            closeClient(fd);
            return 0;
        }
        if (n < 0) {
            if (errno != EAGAIN && errno != EWOULDBLOCK)
                closeClient(fd);
            break;
        }
        c.input.append(buffer, n);
        if (c.input.size() > 65536) {
            closeClient(fd);
            return 0;
        }
        size_t pos;
        while ((pos = c.input.find('\n')) != std::string::npos) {
            auto line = c.input.substr(0, pos);
            c.input.erase(0, pos + 1);
            try {
                message(c, json::parse(line));
            } catch (const json::exception &) {
            }
        }
    }
    return 0;
}
int acceptClient(int, uint32_t, void *) {
    for (int i = 0; i < 8; i++) {
        const int fd = accept4(listener, nullptr, nullptr, SOCK_CLOEXEC | SOCK_NONBLOCK);
        if (fd < 0)
            break;
        ucred cred{};
        socklen_t len = sizeof(cred);
        if (clients.size() >= 64 || getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &cred, &len) || cred.uid != getuid()) {
            close(fd);
            continue;
        }
        auto client = std::make_unique<Client>();
        client->fd = fd;
        client->pid = cred.pid;
        client->source = wl_event_loop_add_fd(g_pCompositor->m_wlEventLoop, fd, WL_EVENT_READABLE, readClient, nullptr);
        if (!client->source) {
            close(fd);
            continue;
        }
        clients.emplace(fd, std::move(client));
    }
    return 0;
}

class GlassPass final : public IPassElement {
    CRenderPass *ownerPass;
    CBox surfaceClip;
    int fd;
    std::string id;
    Region region;

  public:
    GlassPass(CRenderPass *pass, int fd_, std::string id_, Region r, CBox clip)
        : ownerPass(pass), surfaceClip(clip), fd(fd_), id(std::move(id_)), region(std::move(r)) {
        nativePassCounts[ownerPass]++;
    }
    ~GlassPass() override {
        if (auto it = nativePassCounts.find(ownerPass); it != nativePassCounts.end() && !--it->second)
            nativePassCounts.erase(it);
    }
    const char *passName() override { return "TahowLiveGlass"; }
    ePassElementType type() override { return EK_CUSTOM; }
    bool needsLiveBlur(CRenderContext &) override { return true; }
    bool needsPrecomputeBlur(CRenderContext &) override { return false; }
    bool undiscardable(CRenderContext &) override { return true; }
    std::optional<CBox> boundingBox(CRenderContext &ctx) override {
        auto b = region.box.intersection(region.clip);
        b.translate(-ctx.m_data.pMonitor->m_position);
        const double padding = 49. / ctx.m_data.pMonitor->m_scale;
        return CBox{b.x - padding, b.y - padding, b.width + 2 * padding, b.height + 2 * padding};
    }
    std::vector<UP<IPassElement>> draw(CRenderContext &ctx) override {
        if (!provider || region.alpha <= 0 || ctx.m_mode != RENDER_MODE_NORMAL || ctx.m_renderingCapture || ctx.m_renderingSnapshot)
            return {};
        auto backend = g_pHyprRenderer->glBackend();
        if (!backend)
            return {};
        const auto monitor = ctx.m_data.pMonitor.lock();
        if (!monitor)
            return {};
        CBox box = region.box;
        box.translate(-monitor->m_position).scale(monitor->m_scale);
        CBox clip = region.clip;
        clip.translate(-monitor->m_position).scale(monitor->m_scale);
        CRegion drawDamage = ctx.m_data.damage;
        drawDamage.intersect(box).intersect(clip);
        if (!surfaceClip.empty())
            drawDamage.intersect(surfaceClip);
        if (drawDamage.empty())
            return {};
        const auto target = ctx.m_data.currentFB;
        if (!target || !target->getTexture())
            return {};
        auto saved = ctx.saveDrawState();
        const bool oldBlend = backend->blendEnabled();
        CScopeGuard blendGuard{[backend, oldBlend] { backend->blend(oldBlend); }};
        SP<IFramebuffer> blurred;
        {
            auto binding = g_pHyprRenderer->bindTempFB(ctx, target);
            SBlurContext blurContext;
            blurContext.shape = SBlurShape{.box = box, .radius = static_cast<float>(region.radius * monitor->m_scale)};
            blurContext.patternBox = box;
            currentOptics = region.optics;
            drawingNativeMaterial = true;
            CScopeGuard restoreMaterial{[] { drawingNativeMaterial = false; }};
            blurred = provider->blur(ctx, target, 1.F, drawDamage, blurContext);
        }
        if (!blurred || !blurred->getTexture())
            return {};
        ctx.m_data.renderModif = {};
        ctx.m_data.primarySurfaceUVTopLeft = {box.x / blurred->m_size.x, box.y / blurred->m_size.y};
        ctx.m_data.primarySurfaceUVBottomRight = {(box.x + box.width) / blurred->m_size.x, (box.y + box.height) / blurred->m_size.y};
        GL::CHyprOpenGLImpl::STextureRenderData data;
        data.a = region.alpha;
        data.round = std::round(region.radius * monitor->m_scale);
        data.damage = &drawDamage;
        data.allowCustomUV = true;
        data.allowDim = false;
        data.primarySurfaceUVTopLeft = ctx.m_data.primarySurfaceUVTopLeft;
        data.primarySurfaceUVBottomRight = ctx.m_data.primarySurfaceUVBottomRight;
        backend->blend(true);
        backend->renderTexture(ctx, blurred->getTexture(), box, data);
        frames++;
        if (auto it = clients.find(fd); it != clients.end()) {
            auto r = it->second->regions.find(id);
            if (r != it->second->regions.end() && !r->second.presented) {
                r->second.presented = true;
                reply(*it->second, {{"op", "presented"}, {"id", id}});
            }
        }
        return {};
    }
};
// CRenderPass's planner uses the compositor's global blur provider. Our material
// has a larger displacement footprint than the normal Kawase provider, so its
// radius must participate in actual damage propagation, not only its bounds.
// Scope the conservative extra radius to passes containing native glass.
CRegion renderPass(CRenderPass *pass, CRenderContext &ctx, const CRegion &damage) {
    const bool native =
        nativePassCounts.contains(pass) && ctx.m_mode == RENDER_MODE_NORMAL && !ctx.m_renderingCapture && !ctx.m_renderingSnapshot;
    if (native)
        nativeDamageDepth++;
    CScopeGuard restore{[native] {
        if (native)
            nativeDamageDepth--;
    }};
    return reinterpret_cast<RenderPass>(renderHook->m_original)(pass, ctx, damage);
}
void expandDamage(const GL::CHyprGLRenderer *renderer, CRegion &damage, float multiplier) {
    reinterpret_cast<ExpandDamage>(expandHook->m_original)(renderer, damage, multiplier);
    if (nativeDamageDepth > 0)
        damage.expand(49.F * std::max(multiplier, 0.F));
}
CBox mapBox(const CBox &box, const CBox &base, const CSurfacePassElement::SRenderData &surface) {
    const double sx = surface.w / std::max(base.width, 1.), sy = surface.h / std::max(base.height, 1.);
    return CBox{surface.pos.x + (box.x - base.x) * sx, surface.pos.y + (box.y - base.y) * sy, box.width * sx, box.height * sy};
}
void addPass(CRenderPass *pass, UP<IPassElement> &&element) {
    // Insert at the actual layer's position in the pass, not at an arbitrary
    // frame stage. The source therefore contains windows below, never this layer.
    if (element && element->type() == EK_SURFACE) {
        auto *surface = static_cast<CSurfacePassElement *>(element.get());
        const auto layer = surface->m_data.pLS;
        std::string target;
        CBox base;
        pid_t pid = -1;
        if (layer) {
            target = layer->m_namespace;
            base = layer->geometricBox(Desktop::View::IGeometric::GEOMETRIC_GOAL);
            pid = layer->getPID();
        } else if (const auto window = surface->m_data.pWindow; window && window->metadata().title() == "Tahow Preferences") {
            target = "tahow-settings";
            base = window->geometricBox(Desktop::View::IGeometric::GEOMETRIC_GOAL);
            pid = window->backend().pid();
        }
        if (!target.empty() && surface->m_data.mainSurface && !surface->m_data.popup) {
            for (const auto &[fd, c] : clients) {
                if (pid != c->pid)
                    continue;
                for (const auto &[id, r] : c->regions) {
                    if (r.target != target)
                        continue;
                    const auto mon = surface->m_data.pMonitor.lock();
                    if (!mon || (!r.screen.empty() && r.screen != mon->m_name))
                        continue;
                    auto mapped = r;
                    auto sourceBox = r.box, sourceClip = r.clip;
                    if (r.surfaceLocal) {
                        sourceBox.translate(Vector2D{base.x, base.y});
                        sourceClip.translate(Vector2D{base.x, base.y});
                    }
                    mapped.box = mapBox(sourceBox, base, surface->m_data);
                    mapped.clip = mapBox(sourceClip, base, surface->m_data);
                    mapped.radius *=
                        std::max(0., std::min(surface->m_data.w / std::max(base.width, 1.), surface->m_data.h / std::max(base.height, 1.)));
                    mapped.alpha *= std::clamp(surface->m_data.alpha * surface->m_data.fadeAlpha, 0.F, 1.F);
                    reinterpret_cast<Add>(addHook->m_original)(pass, makeUnique<GlassPass>(pass, fd, id, mapped, surface->m_data.clipBox));
                }
            }
        }
    }
    reinterpret_cast<Add>(addHook->m_original)(pass, std::move(element));
}
void shutdown() {
    if (addHook)
        addHook->unhook();
    if (renderHook)
        renderHook->unhook();
    if (expandHook)
        expandHook->unhook();
    if (shaderHook)
        shaderHook->unhook();
    // Nested/redirected passes can also own plugin vtables. Destroy every live
    // GlassPass before dlclose; destructors mutate nativePassCounts, so iterate
    // over a snapshot of the owning pass pointers.
    std::vector<CRenderPass *> owningPasses;
    owningPasses.reserve(nativePassCounts.size());
    for (const auto &[pass, count] : nativePassCounts)
        owningPasses.push_back(pass);
    for (auto *pass : owningPasses)
        pass->removeAllOfType("TahowLiveGlass");
    while (!clients.empty())
        closeClient(clients.begin()->first);
    if (listenerSource) {
        wl_event_source_remove(listenerSource);
        listenerSource = nullptr;
    }
    if (listener >= 0) {
        close(listener);
        listener = -1;
    }
    if (socketOwned)
        unlink(socketPath.c_str());
    socketOwned = false;
    socketPath.clear();
    provider.reset();
    materialShaders.clear();
}
} // namespace
APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }
APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE h) {
    handle = h;
    if (HyprlandAPI::getHyprlandVersion(h).hash != GIT_COMMIT_HASH)
        throw std::runtime_error("Tahow: rebuild against the running Hyprland ABI");
    if (!g_pHyprRenderer->glBackend())
        throw std::runtime_error("Tahow: OpenGL renderer required");
    const auto address = dlsym(RTLD_DEFAULT, "_ZN6Render11CRenderPass3addEON9Hyprutils6Memory14CUniquePointerI12IPassElementEE");
    if (address)
        addHook = HyprlandAPI::createFunctionHook(h, address, reinterpret_cast<void *>(addPass));
    if (!address)
        throw std::runtime_error("Tahow: pass symbol missing");
    if (!addHook)
        throw std::runtime_error("Tahow: hook creation failed");
    if (!addHook->hook())
        throw std::runtime_error("Tahow: hook patch failed");
    try {
        const auto shaderAddress = dlsym(RTLD_DEFAULT, "_ZN6Render2GL15CHyprOpenGLImpl16getShaderVariantENS_23ePreparedFragmentShaderERKNS_14SShaderVariantE");
        if (!shaderAddress) throw std::runtime_error("Tahow: shader variant hook unavailable");
        shaderHook = HyprlandAPI::createFunctionHook(h, shaderAddress, reinterpret_cast<void *>(materialShader));
        if (!shaderHook || !shaderHook->hook()) throw std::runtime_error("Tahow: shader variant hook failed");
        const auto renderAddress = dlsym(RTLD_DEFAULT, "_ZN6Render11CRenderPass6renderERNS_14CRenderContextERKN9Hyprutils4Math7CRegionE");
        const auto expandAddress = dlsym(RTLD_DEFAULT, "_ZNK6Render2GL15CHyprGLRenderer16expandBlurDamageERN9Hyprutils4Math7CRegionEf");
        if (!renderAddress || !expandAddress)
            throw std::runtime_error("Tahow: damage hooks unavailable");
        renderHook = HyprlandAPI::createFunctionHook(h, renderAddress, reinterpret_cast<void *>(renderPass));
        expandHook = HyprlandAPI::createFunctionHook(h, expandAddress, reinterpret_cast<void *>(expandDamage));
        if (!renderHook || !expandHook || !renderHook->hook() || !expandHook->hook())
            throw std::runtime_error("Tahow: damage hook patch failed");
        provider = std::make_unique<GL::CDualKawaseBlurProvider>(*g_pHyprRenderer->glBackend(), makeUnique<Material>());
        socketPath = g_pCompositor->m_instancePath + "/tahow-glass.sock";
        sockaddr_un address{};
        address.sun_family = AF_UNIX;
        if (socketPath.size() >= sizeof(address.sun_path))
            throw std::runtime_error("Tahow: socket path too long");
        std::copy(socketPath.begin(), socketPath.end(), address.sun_path);
        listener = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
        if (listener < 0 || bind(listener, reinterpret_cast<sockaddr *>(&address), sizeof(address)))
            throw std::runtime_error("Tahow: socket bind failed");
        socketOwned = true;
        if (chmod(socketPath.c_str(), 0600) || listen(listener, 16))
            throw std::runtime_error("Tahow: socket setup failed");
        listenerSource = wl_event_loop_add_fd(g_pCompositor->m_wlEventLoop, listener, WL_EVENT_READABLE, acceptClient, nullptr);
        if (!listenerSource)
            throw std::runtime_error("Tahow: event loop registration failed");
    } catch (...) {
        shutdown();
        throw;
    }
    return {"tahow-live-glass", "Live underlay refraction for Tahow, rendered inside the compositor", "Eduardo Augusto and contributors",
            "0.1.0"};
}
APICALL EXPORT void PLUGIN_EXIT() { shutdown(); }
