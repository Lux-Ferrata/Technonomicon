config.load_autoconfig(False)

# One window per page
c.tabs.tabs_are_windows = True
c.tabs.show = 'never'

# Start page
c.url.start_pages = ['https://en.wikipedia.org/wiki/Special:Random']
c.url.default_page = 'https://en.wikipedia.org/wiki/Special:Random'

# Search engines
c.url.searchengines = {
    'DEFAULT': 'https://duckduckgo.com/?q={}',
    'w': 'https://en.wikipedia.org/wiki/Special:Search?search={}',
    'g': 'https://www.google.com/search?q={}',
}

# Dark mode
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.preferred_color_scheme = 'dark'
c.colors.webpage.darkmode.algorithm = 'lightness-cielab'

# Adblock
c.content.blocking.enabled = True
c.content.blocking.method = 'both'

# Privacy
c.content.cookies.accept = 'no-3rdparty'
c.content.geolocation = False

# Incremental search off (matches prior autoconfig.yml setting)
c.search.incremental = False

# Downloads — no prompt, straight to ~/Downloads
c.downloads.location.directory = '~/Downloads'
c.downloads.location.prompt = False

# Session persistence
c.auto_save.session = True

# Statusbar only in insert/hint/command modes
c.statusbar.show = 'in-mode'

# Per-site overrides (migrated from autoconfig.yml)
config.set('content.geolocation', True, 'https://care1.va.gov')
config.set('content.media.audio_video_capture', True, 'https://care1.va.gov')
config.set('content.javascript.clipboard', 'access-paste', 'https://charachorder.io')
config.set('content.javascript.clipboard', 'access-paste', 'https://gemini.google.com')
config.set('content.javascript.clipboard', 'access-paste', 'https://github.com')
config.set('content.register_protocol_handler', True, 'https://calendar.google.com?cid=%25s')

# Bitwarden autofill — ;b fills credentials for the current site
config.bind(';b', "spawn --userscript qute-bitwarden "
            "--dmenu-invocation 'bemenu -i -p Bitwarden' "
            "--password-prompt-invocation 'bemenu -p Password'")
