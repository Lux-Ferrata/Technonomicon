// Unmap all default single-key and compound-key bindings
[
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
  'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  '/', '?', ';', "'", ',', '.', '-', '=', '[', ']', '\\',
  'g0', 'g$', 'gi', 'gf', 'gF', 'gs', 'gp', 'gu', 'gU',
  'gt', 'gT', 'g.', 'go', 'gn', 'gg', 'G',
  'cc', 'cS',
  '<Ctrl-a>', '<Ctrl-b>', '<Ctrl-c>', '<Ctrl-d>', '<Ctrl-e>', '<Ctrl-f>',
  '<Ctrl-g>', '<Ctrl-h>', '<Ctrl-i>', '<Ctrl-j>', '<Ctrl-k>', '<Ctrl-l>',
  '<Ctrl-m>', '<Ctrl-n>', '<Ctrl-o>', '<Ctrl-p>', '<Ctrl-q>', '<Ctrl-r>',
  '<Ctrl-s>', '<Ctrl-t>', '<Ctrl-u>', '<Ctrl-v>', '<Ctrl-w>', '<Ctrl-x>',
  '<Ctrl-y>', '<Ctrl-z>',
].forEach(k => { try { api.unmap(k); } catch(e) {} });

api.unmap('<Ctrl-i>');
api.iunmap('<Ctrl-i>');

// o - open URL in current tab
api.mapkey('o', 'Open URL in current tab', function() {
    api.Front.openOmnibar({type: 'URLs'});
});

// t - open URL in new tab
api.mapkey('t', 'Open URL in new tab', function() {
    api.Front.openOmnibar({type: 'URLs', tabbed: true});
});

// f - link hints (click a link)
api.mapkey('f', 'Click a link', function() {
    Hints.create('', Hints.dispatchMouseClick);
});

// F - open link in new background tab
api.mapkey('F', 'Open link in background tab', function() {
    Hints.create('', function(link) {
        api.RUNTIME('openLink', {
            url: link.href,
            tab: {tabbed: true, active: false},
        });
    });
});

// y - yank current URL to clipboard
api.mapkey('y', 'Yank current URL', function() {
    api.Clipboard.write(window.location.href);
});

// v - enter visual mode
api.mapkey('v', 'Enter visual mode', function() {
    Visual.activate();
});

// Visual mode arrow keys
api.vmap('<ArrowDown>', 'j');
api.vmap('<ArrowUp>', 'k');
api.vmap('<ArrowLeft>', 'h');
api.vmap('<ArrowRight>', 'l');

settings.theme = `
.sk_theme {
    font-family: Input Sans Condensed, Charcoal, sans-serif;
    font-size: 10pt;
    background: #24272e;
    color: #abb2bf;
}
.sk_theme tbody {
    color: #fff;
}
.sk_theme input {
    color: #d0d0d0;
}
.sk_theme .url {
    color: #61afef;
}
.sk_theme .annotation {
    color: #56b6c2;
}
.sk_theme .omnibar_highlight {
    color: #528bff;
}
.sk_theme .omnibar_timestamp {
    color: #e5c07b;
}
.sk_theme .omnibar_visitcount {
    color: #98c379;
}
.sk_theme #sk_omnibarSearchResult ul li:nth-child(odd) {
    background: #303030;
}
.sk_theme #sk_omnibarSearchResult ul li.focused {
    background: #3e4452;
}
#sk_status, #sk_find {
    font-size: 20pt;
}
/* Center the Omnibar like a floating child-frame */
#sk_omnibar {
    width: 60%;
    left: 20%;
}`;
