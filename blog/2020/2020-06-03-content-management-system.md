---
title: Convos as a document and blogging service
image: /screenshots/2020-06-03-webpage.jpg
author: Jan Henning Thorsen
---

A CMS in Convos? Why? How..? [https://convos.chat](https://convos.chat) used to
be powered by [GitHub Pages](https://pages.github.com/), but it is now
powered by "Convos Pages" instead. The CMS support was mainly added to make
it easier to maintain our web page, but can be used by anyone as a generic CMS.

Last week we also changed the domain name from _convos.by_ to
"[convos.chat](https://convos.chat)". We did the switch because the ".by"
domain raised questions by our users and was hard to remember.

The result is a new and shiny webpage that reflects the main Convos design
rules!

[![The new web page](/screenshots/2020-06-03-webpage.jpg)](/screenshots/2020-06-03-webpage.jpg)

## How to create your own content

The custom web page can be created by creating some directories and files in
[$CONVOS_HOME](/doc/config#convos_home).

* __`$CONVOS_HOME/content/index.md`__ will override the index page (`/`) of
  your Convos installation. "[/](/)" does normally just redirect to
  [/login](/login) or [/chat](/chat), so overriding this page is completely
  fine.
* Any file that ends with ".md" in the __`$CONVOS_HOME/content/doc/`__
  directory will be available under the [/doc](/doc) path. A special "index.md"
  file will be served directly from [/doc](/doc) path.
* Blog entries must be created in the "blog" directory with the format
  __`$CONVOS_HOME/content/blog/$YEAR/$YEAR-$MON-$MDAY-$TITLE.md`__. Example
  [$CONVOS_HOME/content/blog/2020/2020-06-03-content-management-system.md](https://github.com/Nordaaker/convos/blob/www.convos.chat/blog/2020/2020-05-14-content-management-system.md).
* Any static file, such as images, can be placed in the
  __`$CONVOS_HOME/content/public/`__ directory. Do be careful though, and avoid
  override any core [Convos files](https://github.com/Nordaaker/convos/tree/master/public).
* Files in the __`$CONVOS_HOME/content/templates/`__ directory can be used to
  add, or override any core [Convos template](//github.com/Nordaaker/convos/tree/master/templates).
  Supported overrides are the __templates/partial/cms*.ep__ files.

See the [www.convos.chat](https://github.com/Nordaaker/convos/tree/www.convos.chat)
branch for a working example, being this web site.

    git clone https://github.com/Nordaaker/convos.git \
      -b www.convos.chat ~/.local/share/convos/content

## Supported markdown

The markdown files support the basic
[Markdown](http://daringfireball.net/projects/markdown/) syntax through the
[Text::Markdown](https://metacpan.org/pod/Text::Markdown) parser. In additon
it supports the following...

### Headings

Headings will have the "id" attribute, which is as
[slug](/doc/Mojo/Util#slugify) of the text inside the heading. The headings
will also be available to be displayed as a "table of content" under the first
heading. See [Supported YAML front-matter](#supported-yaml-front-matter) for
how to display the TOC.

### Markdown inside block tags

    &lt;div markdown>
      ### Some header

          document.querySelector('#code-example');
    &lt;/div>

The content inside a block tag with the "__markdown__" attribute will be
stripped of the whitespace of the first line, before being run through the
markdown parser. This will make it a lot easier to indent the markdown
correctly and read the markup.

### Styling

&lt;style> tags will be merged and moved into &lt;head>.

### FontAwesome icons

    ![fab](github) = &lt;i class="fab fa-github"/>
    ![fas](eye)    = &lt;i class="fas fa-eye"/>

Two special [image](https://daringfireball.net/projects/markdown/basics)
formats will be turned into [FontAwesome](https://fontawesome.com/icons) icons
instead.

* "fas" icons is in the "Solid" category.
* "fab" icons is in the "Brands" category.
* The img url will be prefixed with "fa-" to make up the final class name.

## Supported YAML front-matter

The YAML front-matter can be used to give extra rendering instructions.
Example front-matter:

    ---
    title: Some document title
    description: Some cool description
    image: /some/picture.jpg
    toc: true
    canonical: https://example.com/source/url
    redirect_to: /something/else.html
    ---

* "title" will be used as document title.
* "description" will be used as meta, facebook and twitter description. If no
  description is provided, then the first paragraph found in the document will
  be used.
* "image" can be used to set a custom image that will be displayed when the
  document is displayed on social media, or inside Convos.
* "toc" will cause a "table of content" to be displayed under the main header.
* "canonical" can be set to point to the original source of this conent.
* "redirect_to" will override any other setting and cause a redirect from
  this URL to another relative or absolute URL.

## Automatic content

Any [Perl document](/doc/Convos) available on the system can also be rendered
under the "/doc" path. This feature is currently experimental: The URL might
change in the future, in case it causes too many collisions. This feature
must however be enabled with an environment variable:

    CONVOS_CMS_PERLDOC=1 ./script/convos daemon

## What is next?

It is unlikely to make a WYSIWYG editor for Convos, but if you like this
addition then we would probably take a PR. Like this additon, but don't
want all of Convos? [Convos::Plugin::Cms](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Plugin/Cms.pm)
should be fairly easy to pull out and embed in your own
[Mojolicious](https://mojolicious.org/) project.

So what is next? Check out our
[milestones](https://github.com/nordaaker/convos/milestones) or give us a nuge
or comment on the [issues](https://github.com/nordaaker/convos/issues).

Want to help out with the project? Have a look at the
[developement guide](/doc/develop) or come talk to us in the #convos channel
on irc.freenode.net.
