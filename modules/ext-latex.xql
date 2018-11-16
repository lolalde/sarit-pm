xquery version "3.0";

module namespace pmf="http://sarit.indology.info/teipm/latex";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace latex="http://www.tei-c.org/tei-simple/xquery/functions/latex" at "xmldb:exist:///db/apps/tei-publisher-lib/content/latex-functions.xql";

declare function pmf:document($config as map(*), $node as element(), $class as xs:string+, $content) {
    let $odd := doc($config?odd)
    let $config := latex:load-styles($config, $odd)
    let $fontSize := ($config?font-size, "11pt")[1]
    return (
        "\documentclass[" || $fontSize || "]{" || latex:get-property($config, "class", "book") || "}&#10;",
        "\usepackage{etex}&#10;",
        "\usepackage{eledmac}&#10;",
        "\usepackage{polyglossia}&#10;",
        "\setdefaultlanguage[Script=Devanagari]{sanskrit}&#10;",
        "\setmainfont[Scale=1.0,Script=Devanagari]{Siddhanta}&#10;",
        "\setmainfont[Scale=1.0,Script=Roman]{Siddhanta}&#10;",
        "\usepackage[stable]{footmisc}&#10;",
        "\usepackage[no-sscript]{xltxtra}&#10;" ,
        "% eledmac settings&#10;",
        "\foottwocol{B}&#10;",
        "\linenummargin{outer}&#10;",
        "\sidenotemargin{inner}&#10;",
        "\let\B\relax&#10;",
        "\let\T\relax&#10;",
        "\usepackage{ragged2e}&#10;",
        "%\usepackage{setspace}&#10;",
        "%\usepackage{colortbl}&#10;",
        "\usepackage{fancyhdr}&#10;",
        "\usepackage{xcolor}&#10;",
        "%\usepackage[normalem]{ulem}&#10;",
        "\usepackage{marginfix}&#10;",
        "\usepackage[a4paper, twoside, top=25mm, bottom=35mm, outer=40mm, inner=20mm, heightrounded, marginparwidth=25mm, marginparsep=5mm]{geometry}&#10;",
        "\usepackage{graphicx}&#10;",
        "\usepackage{hyperref}&#10;",
        "\usepackage{ifxetex}&#10;",
        "\usepackage{longtable}&#10;",
        "%\usepackage[maxfloats=64]{morefloats}&#10;",
        "\usepackage{listings}&#10;",
        "\righthyphenmin=2",
        "\lefthyphenmin=2",
        "\lstset{&#10;",
        "basicstyle=\small\ttfamily,",
        "columns=flexible,",
        "breaklines=true",
        "}&#10;",
        "\pagestyle{fancy}&#10;",
        "\fancyhf{}&#10;",
        "%\def\theendnote{\@alph\c@endnote}&#10;",
        "\def\Gin@extensions{.pdf,.png,.jpg,.mps,.tif}&#10;",
        "\hyperbaseurl{}&#10;",
        if (exists($config?image-dir)) then
            "\graphicspath{" ||
            string-join(
                for $dir in $config?image-dir return "{" || $dir || "}"
            ) ||
            "}&#10;"
        else
            (),
        "\def\tableofcontents{\section*{\contentsname}\@starttoc{toc}}&#10;",
        "\thispagestyle{empty}&#10;",
        $config("latex-styles"),
        "\begin{document}&#10;",
        "%\setlength{\parindent}{0pt}&#10;",
        "%\setstretch{1.3}&#10;",
        "%\tolerance=1000",
        "%\hyphenpenalty=100&#10;",
        if (latex:get-property($config, "class", "book") = "book") then "\mainmatter&#10;" else (),
        "\fancyhead[EL,OR]{\fontsize{8}{11}\selectfont\thepage}&#10;",
        "\fancyhead[ER]{\fontsize{8}{11}\selectfont\leftmark}&#10;",
        "\fancyhead[OL]{\fontsize{8}{11}\selectfont\leftmark}&#10;",
        $config?apply-children($config, $node, $content),
        "\end{document}"
    )
};

declare function pmf:break($config as map(*), $node as element(), $class as xs:string+, $content, $type as xs:string, $label as item()*) {
    switch($type)
        case "page" return
            if ($node/@ed) then
                "\marginpar{" || $node/@ed || ": p." || $node/@n || "}"
            else
                "\marginpar{p." || $node/@n || "}"
        default return
            ()
};

declare function pmf:note($config as map(*), $node as element(), $class as xs:string+, $content as item()*, $place as xs:string?, $label as xs:string?) {
    if ($config?skip-footnotes) then
        ()
    else
        switch($place)
            case "margin" return (
                "\marginpar{" || latex:get-content($config, $node, $class, $content) || "}"
            )
            default return (
                string-join((
                    if ($node/parent::tei:head) then
                        "\protect"
                    else
                        (),
                    "\footnote{" || latex:get-content($config, $node, $class, $content) || "}"
                ))
            )
};
