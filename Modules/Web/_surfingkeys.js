// 1. Remove mapkey `Ctrl-i` to disable the Vim editor
api.unmap('<Ctrl-i>');
api.iunmap('<Ctrl-i>'); // Ensures it is disabled in text input fields too

// Map 'o' to open a URL in the current tab (aliases 'go')
api.map('o', 'go');

// 2. Map Shift+f ('F') to open a link in non-active new tab (aliases 'c')
api.map('F', 'c');

// 3. Map Arrow Keys for Visual Mode (vmap targets visual mode specifically)
api.vmap('<ArrowDown>', 'j');
api.vmap('<ArrowUp>', 'k');
api.vmap('<ArrowLeft>', 'h');
api.vmap('<ArrowRight>', 'l');

// 4. Set Dark Theme (Using the built-in generator's code, plus your centered menu!)
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
