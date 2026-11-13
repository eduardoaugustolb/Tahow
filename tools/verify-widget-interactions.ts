import {mkdtempSync,cpSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const temporary=mkdtempSync('/tmp/tahow-widget-test-');
try {
    cpSync('integrations/widgets',temporary+'/widgets',{recursive:true});
    writeFileSync(temporary+'/shell.qml',readFileSync('tools/verify-widget-interactions.qml','utf8').replace('../integrations/widgets/content','./widgets/content'));
    const output=execFileSync('qs',['-p',temporary+'/shell.qml'],{env:{...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software'},encoding:'utf8',timeout:5000});
    if(!output.includes('WIDGET_INTERACTIONS_OK'))throw new Error(output);
    console.log('Widget session controls OK: inert construction, explicit lock and confirmation for destructive actions (fake service).');
} finally {rmSync(temporary,{recursive:true,force:true});}
