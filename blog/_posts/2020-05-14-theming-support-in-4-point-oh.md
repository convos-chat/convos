---
layout: post
title: Theming support in Convos 4.00
---

Convos 4.00 made it a lot simpler to define custom themes.
[Previously](/2019/11/2/custom-styling.html) you had to modify the source code
and build your own version of Convos. This process was way to complicated and
unnecessarily.

<!--more-->

In the 4.xx version of Convos, it's enough to drop a custom CSS file into your
[$CONVOS_HOME](/doc/faq.html) folder, and you are good to go.

## Where should I place my theme files?

The default location is `$CONVOS_HOME/themes/`, which often translates into
`$HOME/.local/share/convos/themes/`. Creating a new theme is as simple as
putting some CSS into a file like
`$HOME/.local/share/convos/themes/My-Cool-Theme.css`.

## How will Convos find the new theme?

Themes will be looked up when Convos is started, as well as on an interval
while running. This means that if a new theme is created, then it should be
available in the web gui after just a couple of seconds.

## What should go into a custom theme file?

There are no real requirements to the content of the file (except of being
valid CSS), but it is highly suggested to add the following header:

```css
/*
 * name: My-Cool-Theme
 * color-scheme: dark
 */
```

The "color-scheme" is only useful if you have both a "light" and a "dark"
version of the theme. The filename will be completely ignored if the header
exist, so you can name the file whatever you want.

The rest of the file should mostly contain variable definitions.
[github.com/Nordaaker/convos/blob/master/assets/sass/_variables.scss](https://github.com/Nordaaker/convos/blob/master/assets/sass/_variables.scss)
shows the available variables that you can override. Here is an example of a
custom theme that will look the same as the default "Convos" light theme, but
will have a much bigger font size:

```css
/*
 * name: I-Like-Big-Text-And-I-Cannot-Lie
 * color-scheme: light
 */

:root {
  --font-size: 24px;
}
```

Here is another example, where the theme is based on the default dark version
of Convos:

```css
/*
 * name: I-Like-Big-Text-And-I-Cannot-Lie
 * color-scheme: dark
 */

@import './convos_color-scheme-dark.css?v=4.03';

:root {
  --font-size: 24px;
}
```

## Where to go from here?

You can look at the bundled theme files at
[GitHub](https://github.com/Nordaaker/convos/tree/master/public/themes) for
inspiration and examples. If you're happy with the theme, then please consider
[sharing](https://github.com/Nordaaker/convos/pulls) it with the Convos
community.

Got more questions? Join us in [#convos](irc://irc.freenode.net/%23convos)
at freenode.net!

Happy theming!
