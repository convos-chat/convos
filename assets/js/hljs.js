import hljs from 'highlight.js/lib/core';
import hljsLineNumbers from './hljs-line-numbers';

// TODO: Figure out a better default list.
// The reasons behind this list are listed below.

// 1. Add languages that are used within Convos
import dockerfile from 'highlight.js/lib/languages/dockerfile';
import javascript from 'highlight.js/lib/languages/javascript';
import markdown from 'highlight.js/lib/languages/markdown';
import mojolicious from 'highlight.js/lib/languages/mojolicious';
import perl from 'highlight.js/lib/languages/perl';
import scss from 'highlight.js/lib/languages/scss';
import xml from 'highlight.js/lib/languages/xml';

// 2. Add some languages that are very different from those that fall under #1,
// but should cover a "family" of langauges.
import go from 'highlight.js/lib/languages/go';
import nginx from 'highlight.js/lib/languages/nginx';
import python from 'highlight.js/lib/languages/python';
import shell from 'highlight.js/lib/languages/shell';

// 3. Add other common language types
import css from 'highlight.js/lib/languages/css';
import diff from 'highlight.js/lib/languages/diff';
import http from 'highlight.js/lib/languages/http';
import yaml from 'highlight.js/lib/languages/yaml';

hljs.registerLanguage('css', css);
hljs.registerLanguage('diff', diff);
hljs.registerLanguage('dockerfile', dockerfile);
hljs.registerLanguage('go', go);
hljs.registerLanguage('http', http);
hljs.registerLanguage('javascript', javascript);
hljs.registerLanguage('markdown', markdown);
hljs.registerLanguage('mojolicious', mojolicious);
hljs.registerLanguage('nginx', nginx);
hljs.registerLanguage('perl', perl);
hljs.registerLanguage('python', python);
hljs.registerLanguage('scss', scss);
hljs.registerLanguage('shell', shell);
hljs.registerLanguage('xml', xml);
hljs.registerLanguage('yaml', yaml);

hljsLineNumbers(hljs);

export default hljs;
