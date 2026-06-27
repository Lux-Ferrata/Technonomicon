// Disable all default keybindings
api.unmapAllExcept([]);
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
