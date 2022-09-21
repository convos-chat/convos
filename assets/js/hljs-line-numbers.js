export default function(hljs) {
  let isInitialized = false;

  hljs.lineNumbersBlock = function(element, options) {
    if (!isInitialized) {
      isInitialized = true;
    }

    hljs.highlightBlock(element, options);
    element.innerHTML = lineNumbersInternal(element, options);
  };
}

/*
 * The rest of the code is from https://github.com/wcoder/highlightjs-line-numbers.js v2.7.0,
 * but with some modifications:
 * - Need to pass the rules in .eslintrc.js
 * - No need for format(), since `...` can be used instead
 * - addStyles() is moved into the _hljs.scss
 * - initLineNumbersOnLoad() and documentReady() is not in use in Convos
 * - Not sure what lineNumbersValue() was used for, so it is also removed
 */

    var TABLE_NAME = 'hljs-ln',
        LINE_NAME = 'hljs-ln-line',
        CODE_BLOCK_NAME = 'hljs-ln-code',
        NUMBERS_BLOCK_NAME = 'hljs-ln-numbers',
        NUMBER_LINE_NAME = 'hljs-ln-n',
        DATA_ATTR_NAME = 'data-line-number',
        BREAK_LINE_REGEXP = /\r\n|\r|\n/g;


    function isHljsLnCodeDescendant(domElt) {
        var curElt = domElt;
        while (curElt) {
            if (curElt.className && curElt.className.indexOf('hljs-ln-code') !== -1) {
                return true;
            }
            curElt = curElt.parentNode;
        }
        return false;
    }

    function getHljsLnTable(hljsLnDomElt) {
        var curElt = hljsLnDomElt;
        while (curElt.nodeName !== 'TABLE') {
            curElt = curElt.parentNode;
        }
        return curElt;
    }

    // Function to workaround a copy issue with Microsoft Edge.
    // Due to hljs-ln wrapping the lines of code inside a <table> element,
    // itself wrapped inside a <pre> element, window.getSelection().toString()
    // does not contain any line breaks. So we need to get them back using the
    // rendered code in the DOM as reference.
    function edgeGetSelectedCodeLines(selection) {
        // current selected text without line breaks
        var selectionText = selection.toString();

        // get the <td> element wrapping the first line of selected code
        var tdAnchor = selection.anchorNode;
        while (tdAnchor.nodeName !== 'TD') {
            tdAnchor = tdAnchor.parentNode;
        }

        // get the <td> element wrapping the last line of selected code
        var tdFocus = selection.focusNode;
        while (tdFocus.nodeName !== 'TD') {
            tdFocus = tdFocus.parentNode;
        }

        // extract line numbers
        var firstLineNumber = parseInt(tdAnchor.dataset.lineNumber, 10);
        var lastLineNumber = parseInt(tdFocus.dataset.lineNumber, 10);

        // multi-lines copied case
        if (firstLineNumber !== lastLineNumber) {

            var firstLineText = tdAnchor.textContent;
            var lastLineText = tdFocus.textContent;

            // if the selection was made backward, swap values
            if (firstLineNumber > lastLineNumber) {
                var tmp = firstLineNumber;
                firstLineNumber = lastLineNumber;
                lastLineNumber = tmp;
                tmp = firstLineText;
                firstLineText = lastLineText;
                lastLineText = tmp;
            }

            // discard not copied characters in first line
            while (selectionText.indexOf(firstLineText) !== 0) {
                firstLineText = firstLineText.slice(1);
            }

            // discard not copied characters in last line
            while (selectionText.lastIndexOf(lastLineText) === -1) {
                lastLineText = lastLineText.slice(0, -1);
            }

            // reconstruct and return the real copied text
            var selectedText = firstLineText;
            var hljsLnTable = getHljsLnTable(tdAnchor);
            for (var i = firstLineNumber + 1 ; i < lastLineNumber ; ++i) {
                var codeLineSel = `.${CODE_BLOCK_NAME}[${DATA_ATTR_NAME}="${i}"]`;
                var codeLineElt = hljsLnTable.querySelector(codeLineSel);
                selectedText += '\n' + codeLineElt.textContent;
            }
            selectedText += '\n' + lastLineText;
            return selectedText;
        // single copied line case
        } else {
            return selectionText;
        }
    }

    // ensure consistent code copy/paste behavior across all browsers
    // (see https://github.com/wcoder/highlightjs-line-numbers.js/issues/51)
    document.addEventListener('copy', function(e) {
        // get current selection
        var selection = window.getSelection();
        // override behavior when one wants to copy line of codes
        if (isHljsLnCodeDescendant(selection.anchorNode)) {
            var selectionText;
            // workaround an issue with Microsoft Edge as copied line breaks
            // are removed otherwise from the selection string
            if (window.navigator.userAgent.indexOf('Edge') !== -1) {
                selectionText = edgeGetSelectedCodeLines(selection);
            } else {
                // other browsers can directly use the selection string
                selectionText = selection.toString();
            }
            e.clipboardData.setData('text/plain', selectionText);
            e.preventDefault();
        }
    });

    function lineNumbersInternal (element, options) {
        // define options or set default
        options = options || {singleLine: false};

        // convert options
        var firstLineIndex = options.singleLine ? 0 : 1;

        duplicateMultilineNodes(element);

        return addLineNumbersBlockFor(element.innerHTML, firstLineIndex);
    }

    function addLineNumbersBlockFor (inputHtml, firstLineIndex) {

        var lines = getLines(inputHtml);

        // if last line contains only carriage return remove it
        if (lines[lines.length-1].trim() === '') {
            lines.pop();
        }

        if (lines.length > firstLineIndex) {
            var html = '';

            for (var i = 0, l = lines.length; i < l; i++) {
                let n = i + 1;
                html += '<tr>'
                        + `<td class="${LINE_NAME} ${NUMBERS_BLOCK_NAME}" ${DATA_ATTR_NAME}="${n}">`
                          + `<div class="${NUMBER_LINE_NAME}" ${DATA_ATTR_NAME}="${n}"></div>`
                        + '</td>'
                        + `<td class="${LINE_NAME} ${CODE_BLOCK_NAME}" ${DATA_ATTR_NAME}="${n}">`
                          + (lines[i].length > 0 ? lines[i] : ' ')
                        + '</td>'
                      + '</tr>';
            }

            return `<table class="${TABLE_NAME}">${html}</table>`;
        }

        return inputHtml;
    }

    /**
     * Recursive method for fix multi-line elements implementation in highlight.js
     * Doing deep passage on child nodes.
     * @param {HTMLElement} element
     */
    function duplicateMultilineNodes (element) {
        var nodes = element.childNodes;
        for (var node in nodes) {
            if (Object.hasOwn(nodes, node)) {
                var child = nodes[node];
                if (getLinesCount(child.textContent) > 0) {
                    if (child.childNodes.length > 0) {
                        duplicateMultilineNodes(child);
                    } else {
                        duplicateMultilineNode(child.parentNode);
                    }
                }
            }
        }
    }

    /**
     * Method for fix multi-line elements implementation in highlight.js
     * @param {HTMLElement} element
     */
    function duplicateMultilineNode (element) {
        var className = element.className;

        if ( ! /hljs-/.test(className)) return;

        var lines = getLines(element.innerHTML);

        for (var i = 0, result = ''; i < lines.length; i++) {
            var lineText = lines[i].length > 0 ? lines[i] : ' ';
            result += `<span class="${className}">${lineText}</span>\n`;
        }

        element.innerHTML = result.trim();
    }

    function getLines (text) {
        if (text.length === 0) return [];
        return text.split(BREAK_LINE_REGEXP);
    }

    function getLinesCount (text) {
        return (text.trim().match(BREAK_LINE_REGEXP) || []).length;
    }
