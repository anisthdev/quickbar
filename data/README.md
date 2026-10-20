# Data

`glyphnames.json` is Nerd Fonts' list of glyph names and codepoints
(version 3.5.1), from https://github.com/ryanoasis/nerd-fonts, where it is
released under the MIT License, Copyright (c) 2014 Ryan L McIntyre. The
glyph picker (modules/GlyphPicker.qml) reads it.

`emoji.json` is a trimmed copy of emojibase-data's English compact list
(version 16.0.3), from https://github.com/milesj/emojibase, where it is
released under the MIT License, Copyright (c) 2017-2019 Miles Johnson.
Each entry keeps the emoji, its name, keywords, group and codepoints; skin
tones and hair components are left out. The emoji picker
(modules/EmojiPicker.qml) reads it.
