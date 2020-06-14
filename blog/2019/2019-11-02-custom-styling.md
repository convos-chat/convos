---
title: How to define custom styling for Convos
author: Jan Henning Thorsen
---

This post is outdated. If you want to see a more recent post about theming,
go to [Theming support in Convos 4.00](/blog/2020/5/14/theming-support-in-4-point-oh).

<!--more-->

[Convos 1.x](/blog/2019/10/26/convos-one-point-oh) does no longer support
defining custom assets in your [CONVOS_HOME](/doc/config) directory.

We might make this process simpler in the future, but for now you have
to modify the source code. Please have a look at the
[development guide](/doc/develop) to get started. This post will
build on top of that guide with an example on how to make your own
custom theme.

To be able to define a new theme, you must get Convos version 1.01 or
later.

## Theme setup

The [_themes.scss](https://github.com/Nordaaker/convos/blob/1.01/assets/sass/_themes.scss)
file is used to define all the different themes. When writing this post, there
are two themes defined:

1. The "[light](https://github.com/Nordaaker/convos/blob/1.01/assets/sass/themes/_light.scss)"
   theme is the default theme for Convos and acts as a base for other themes.

2. The "[dark](https://github.com/Nordaaker/convos/blob/1.01/assets/sass/themes/_dark.scss)"
   theme is default if your OS and browser is configured to "dark mode".

Either of the themes can be selected in "settings":

[![Picture of Convos settings](/screenshots/2019-11-02-settings.jpg)](/screenshots/2019-11-02-settings.jpg)

## Customize the default colors

Since you're in control of the source code, you can always change
[_light.scss](https://github.com/Nordaaker/convos/blob/1.01/assets/sass/themes/_light.scss)
directly, but it is advised to create a new theme instead.

A new theme can be defined by following these steps:

1. Create a new (empty) file in [assets/sass/themes](https://github.com/Nordaaker/convos/tree/1.01/assets/sass/themes).
   In this example we will call it `_blue.scss`.

2. Edit [_themes.scss](https://github.com/Nordaaker/convos/blob/1.01/assets/sass/_themes.scss)
   and add a line after `@import 'themes/light';`, where you import the new theme:

       @import 'themes/dark';
       @import 'themes/light';
       @import 'themes/blue'; // Same name as in step #1

To make the theme actually affect the layout, you have to fill `_blue.scss` with
some overrides. Have a look at the
[_light.scss](https://github.com/Nordaaker/convos/blob/1.01/assets/sass/themes/_light.scss)
theme to see what you can override, but here is an example:

    :root {
      --sidebar-left-bg: #425386;
      --sidebar-left-search-focus-bg: #203163;
    }

One way of choosing colors, is by poking into the development tools of your favorite
browser.

## Define a new theme

Instead of overriding the default, you can define a new theme that can be selected
from the "settings" page.

This is done by changing the first line in `_blue.scss` to `html.theme-blue {`.
The file should look like this afterwards:

    html.theme-blue {
      --sidebar-left-bg: #425386;
      --sidebar-left-search-focus-bg: #203163;
    }

In addition you have to make the theme available in the "settings" page.
This is done by running the [latest version](https://github.com/Nordaaker/convos/issues/404)
of `t/production-resources.t`:

    prove -vl t/production-resources.t

## Change the highlight colors

The highlighting of code snippets is done by
[highlight.js](https://github.com/highlightjs/highlight.js). There are a lot of
themes available, so instead of defining one from scratch, you can probably
just select one from
[the list](https://github.com/highlightjs/highlight.js/tree/master/src/styles).

After choosing a new theme, you can add it to you style:

    html.theme-blue {
      @import '../../../node_modules/highlight.js/scss/tomorrow-night-blue.scss';
      --sidebar-left-bg: #425386;
      --sidebar-left-search-focus-bg: #203163;
    }

## Recomondations

1. We recommend not starting to fiddle around with CSS selectors. If you want
   to style something that isn't defined as a variable, then please open an
   [issue](https://github.com/Nordaaker/convos/issues) describing what you
   want to customize.

2. If you're making a dark theme, then extend the existing dark theme so you
   get the new default changes. Example:

        html.theme-dark-blue {
          @import 'dark.scss';
          --sidebar-left-bg: #1c243c;
        }

3. Share your theme! If you make a new theme and want to contribute to the
   project, then please open a [pull request](https://github.com/Nordaaker/convos/pulls).
   When doing so, please upload a screenshot as well, so it's easier to see
   how it looks.

4. Be a bit creative when naming your theme: "blue" is not a very good name
   &mdash; instead you could use a name from one of the themes in
   [highlight.js](https://github.com/highlightjs/highlight.js/tree/master/src/styles).

## Making your theme available in production

If you followed the [development guide](/doc/develop) then Convos should
automatically reload and your changes gets available in development mode
using the command below:

    ./script/convos dev

After you're happy with the changes you can build the production version
of the assets with the following command:

    BUILD_ASSETS=1 prove -l t/production-resources.t

That should be it! Happy theming!

Drop us a question in [#convos](irc://chat.freenode.net:6697/convos) on
chat.freenode.net if something does not work as expectd.
