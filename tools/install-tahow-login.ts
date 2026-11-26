import { randomUUID } from 'node:crypto';
import {
    chmodSync, copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readlinkSync,
    readFileSync, renameSync, rmSync, symlinkSync, unlinkSync, writeFileSync,
} from 'node:fs';
import { dirname, join, resolve } from 'node:path';

export function configureLogin(
    system: string, state: string,
    install?: { service: string; override: string },
) {
    const alias = join(system, 'display-manager.service');
    const override = join(system, 'greetd.service.d/90-tahow-login.conf');
    const backup = join(state, 'previous-display-manager');
    const marker = join(state, 'activation.lock');
    mkdirSync(state, { recursive: true });
    mkdirSync(marker);
    const temporary = join(system, '.tahow-' + randomUUID());
    const overrideStage = override + '.' + randomUUID();
    let savedBackup = false;
    try {
        const current = lstatSync(alias, { throwIfNoEntry: false });
        if (current && !current.isSymbolicLink()) throw new Error('Expected display-manager.service to be a symlink');
        const target = current ? readlinkSync(alias) : '';
        if (target === '/dev/null') throw new Error('display-manager.service is masked');
        if (install) {
            if (!existsSync(backup)) {
                if (existsSync(override)) throw new Error('Tahow login override already exists without a backup');
                writeFileSync(backup, target, { flag: 'wx', mode: 0o600 });
                savedBackup = true;
            } else if (target !== install.service) {
                throw new Error('The active display-manager selection changed; remove Tahow login before reinstalling');
            }
            mkdirSync(dirname(override), { recursive: true });
            writeFileSync(overrideStage, install.override, { mode: 0o644, flag: 'wx' });
            symlinkSync(install.service, temporary);
            renameSync(temporary, alias);
            try {
                renameSync(overrideStage, override);
            } catch (error) {
                if (target) {
                    symlinkSync(target, temporary);
                    renameSync(temporary, alias);
                } else unlinkSync(alias);
                throw error;
            }
        } else {
            if (!existsSync(backup)) throw new Error('Tahow login has no saved display-manager selection');
            const previous = readFileSync(backup, 'utf8');
            // An administrator may already have chosen a different display manager.
            if (target.endsWith('/greetd.service')) {
                if (previous) {
                    symlinkSync(previous, temporary);
                    renameSync(temporary, alias);
                } else unlinkSync(alias);
            }
            rmSync(override, { force: true });
            unlinkSync(backup);
        }
    } catch (error) {
        if (savedBackup) unlinkSync(backup);
        throw error;
    } finally {
        rmSync(temporary, { force: true });
        rmSync(overrideStage, { force: true });
        rmSync(marker, { recursive: true });
    }
}

function executable(name: string) {
    // Boot-time commands must come from system directories.
    const command = Bun.which(name, { PATH: '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' });
    if (!command || !/^\/[\w./-]+$/.test(command)) throw new Error(`Install ${name} through your distribution first`);
    return command;
}

function installLogin() {
    const system = '/etc/systemd/system';
    const state = '/usr/local/lib/tahow-login';
    const greeterUser = process.argv[3] || 'greeter';
    if (process.getuid!() !== 0) throw new Error('Run the login installer with sudo');
    if (!existsSync('/run/systemd/system')) throw new Error('Tahow login requires systemd');
    if (process.argv[2] === '--restore') {
        configureLogin(system, state);
        console.log('Previous login selection restored for the next boot.');
        return;
    }
    if (process.argv[2] !== '--install' || !/^[a-z_][a-z0-9_-]*$/.test(greeterUser)) throw new Error('Usage: install-tahow-login.ts --install [greeter-account] | --restore');

    const account = Bun.spawnSync(['id', '-u', greeterUser], { stderr: 'ignore' });
    if (account.exitCode || Number(account.stdout.toString()) <= 0) throw new Error('A dedicated non-root greetd account is required');
    const greetd = executable('greetd');
    const cage = executable('cage');
    const qs = executable('qs');
    const session = executable('Hyprland');
    const fallback = executable('agreety');
    const service = ['/etc/systemd/system', '/usr/lib/systemd/system', '/lib/systemd/system']
        .map(dir => join(dir, 'greetd.service')).find(existsSync);
    if (!service || !existsSync('/etc/pam.d/greetd')) throw new Error('Install greetd with its distribution service and PAM configuration first');

    mkdirSync(state, { recursive: true, mode: 0o755 });
    const edition = mkdtempSync(join(state, 'release-'));
    try {
        const view = join(edition, 'integrations/greetd');
        const i18n = join(edition, 'locales');
        const root = resolve(import.meta.dir, '..');
        mkdirSync(view, { recursive: true });
        mkdirSync(i18n, { recursive: true });
        for (const file of ['shell.qml', 'client.ts']) copyFileSync(join(root, 'integrations/greetd', file), join(view, file));
        for (const file of ['en-US.json', 'pt-BR.json']) copyFileSync(join(root, 'locales', file), join(i18n, file));
        copyFileSync(process.execPath, join(edition, 'bun'));
        chmodSync(join(edition, 'bun'), 0o755);
        chmodSync(edition, 0o755);
        const command = `TAHOW_GREETER_BUN=${edition}/bun TAHOW_LOGIN_SESSION=${session} QT_QPA_PLATFORM=wayland ${cage} -s -- ${qs} -p ${view}/shell.qml || exec ${fallback} -c ${session}`;
        const config = join(edition, 'greetd.toml');
        writeFileSync(config, `[terminal]\nvt = 1\n\n[general]\nsource_profile = false\n\n[default_session]\ncommand = ${JSON.stringify(command)}\nuser = "${greeterUser}"\n`);
        configureLogin(system, state, {
            service,
            override: `[Unit]\nConflicts=getty@tty1.service\nAfter=getty@tty1.service\n\n[Service]\nLimitCORE=0\nExecStart=\nExecStart=${greetd} --config ${config}\n`,
        });
    } catch (error) {
        rmSync(edition, { recursive: true, force: true });
        throw error;
    }
    console.log('Tahow login selected for the next boot. Restore with ./install.sh --restore-login.');
}

if (import.meta.main) {
    try { installLogin(); }
    catch (error) {
        console.error(error instanceof Error ? error.message : 'Tahow login installation failed');
        process.exitCode = 1;
    }
}
