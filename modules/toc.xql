module namespace toc = "http://sarit.indology.info/app/toc";

import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";
import module namespace tei-to-html="http://exist-db.org/xquery/app/tei2html" at "tei2html.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(:You can always see three levels: the current level, is siblings, its parent and its children. 
This means that you can always go up and down (and sideways).
One could leave out or elide the siblings. :)
(:template function in view-work.html:)
declare 
    %templates:default("full", "false")
    %templates:default("view", "div")
function toc:outline($node as node(), $model as map(*), $full as xs:boolean, $view as xs:string) {
    let $position := $model("data")
    let $root := if ($full) then $position/ancestor-or-self::tei:TEI else $position
    let $long := $node/@data-template-details/string()
    let $work := $root/ancestor-or-self::tei:TEI
    return
        if (
            exists($work/tei:text/tei:front/tei:titlePage) or 
            exists($work/tei:text/tei:front/tei:div) or 
            exists($work/tei:text/tei:body/tei:div) or 
            exists($work/tei:text/tei:back/tei:div)
           ) 
        then (
            <ul class="contents">{
                typeswitch($root)
                    case element(tei:div) return
                        (:if it is not the whole work:)
                        toc:generate-toc-from-div($root, $long, $position, $view) 
                    case element(tei:titlePage) return
                        (:if it is not the whole work:)
                        toc:generate-toc-from-div($root, $long, $position, $view)
                    default return
                        (:if it is the whole work:)
                        (
                        if ($work/tei:text/tei:front/tei:titlePage, $work/tei:text/tei:front/tei:div)
                        then
                            <div class="text-front">
                                <h6>Front Matter</h6>
                                <ul>
                                {for $div in 
                                    (
                                    $work/tei:text/tei:front/tei:titlePage, 
                                    $work/tei:text/tei:front/tei:div 
                                    )
                                return toc:toc-div($div, $long, $position, 'list-item', $view)
                                }
                                </ul>
                            </div>
                            else ()
                        ,
                        <div class="text-body">
                        <h6>{if ($work/tei:text/tei:front/tei:titlePage, $work/tei:text/tei:front/tei:div, $work/tei:text/tei:back/tei:div) then 'Text' else ''}</h6>
                        <ul>
                            {for $div in 
                                (
                                $work/tei:text/tei:body/tei:div 
                                )
                            return toc:toc-div($div, $long, $position, 'list-item', $view)
                            }
                        </ul>
                        </div>
                        ,
                        if ($work/tei:text/tei:back/tei:div)
                        then
                            <div class="text-back">
                            <h6>Back Matter</h6>
                            <ul>
                            {for $div in 
                                (
                                $work/tei:text/tei:back/tei:div 
                                )
                            return toc:toc-div($div, $long, $position, 'list-item', $view)
                            }
                            </ul>
                            </div>
                        else ()
                        )
            }</ul>
        ) else ()
};

(:based on Joe Wicentowski, http://digital.humanities.ox.ac.uk/dhoxss/2011/presentations/Wicentowski-XMLDatabases-materials.zip:)
declare %private function toc:generate-toc-from-divs($node, $current as element()?, $long as xs:string?,
    $view as xs:string) {
    if ($node/tei:div) 
    then
        <ul style="display: none">{
            for $div in $node/tei:div
            return toc:toc-div($div, $long, $current, 'list-item', $view)
        }</ul>
    else ()
};

declare %private function toc:generate-toc-from-div($root, $long, $position, $view) {
    (:if it has divs below itself:)
    <li>{
    if ($root/tei:div) then
        (
        if ($root/parent::tei:div) 
        (:show the parent:)
        then toc:toc-div($root/parent::tei:div, $long, $position, 'no-list-item', $view) 
        (:NB: this creates an empty <li> if there is no div parent:)
        (:show nothing:)
        else ()
        ,
        for $div in $root/preceding-sibling::tei:div
        return toc:toc-div($div, $long, $position, 'list-item', $view)
        ,
        toc:toc-div($root, $long, $position, 'list-item', $view)
        ,
        <ul>
            {
            for $div in $root/tei:div
            return toc:toc-div($div, $long, $position, 'list-item', $view)
            }
        </ul>
        ,
        for $div in $root/following-sibling::tei:div
        return toc:toc-div($div, $long, $position, 'list-item', $view)
        )
    else
    (
        (:if it is a leaf:)
        (:show its parent:)
        if ($root/parent::tei:div) then
            toc:toc-div($root/parent::tei:div, $long, $position, 'no-list-item', $view)
        else
            ()
        ,
        (:show its preceding siblings:)
        <ul>
            {
            for $div in $root/preceding-sibling::tei:div
            return toc:toc-div($div, $long, $position, 'list-item', $view)
            ,
            (:show itself:)
            (:NB: should not have link:)
            toc:toc-div($root, $long, $position, 'list-item', $view)
            ,
            (:show its following siblings:)
            for $div in $root/following-sibling::tei:div
            return toc:toc-div($div, $long, $position, 'list-item', $view)
            }
        </ul>
        )
       }</li>
};

(:based on Joe Wicentowski, http://digital.humanities.ox.ac.uk/dhoxss/2011/presentations/Wicentowski-XMLDatabases-materials.zip:)
declare %private function toc:toc-div($div, $long as xs:string?, $current as element()?, $list-item as xs:string?,
    $view as xs:string) {
    let $div-id := 
        util:document-name($div) || "?root=" || util:node-id($div) || "&amp;view=" || $view
    return
        if ($list-item eq 'list-item')
        then
            if (count($div/ancestor::tei:div) < 2)
            then
                <li class="{if ($div is $current) then 'current' else 'not-current'}">
                    {
                        if ($div/tei:div and count($div/ancestor::tei:div) < 1) then
                            <a href="#" class="toc-expand"><i class="material-icons">add</i></a>
                        else
                            ()
                    }
                    <a href="{$div-id}">{toc:derive-title($div)}</a> 
                    {if ($long eq 'yes') then toc:generate-toc-from-divs($div, $current, $long, $view) else ()}
                </li>
            else ()
        else
            <a href="{$div-id}.html">{toc:derive-title($div)}</a> 
};

(:based on Joe Wicentowski, http://digital.humanities.ox.ac.uk/dhoxss/2011/presentations/Wicentowski-XMLDatabases-materials.zip:)
declare %private function toc:derive-title($div) {
    typeswitch ($div)
        case element(tei:div) return
            let $n := $div/@n/string()
            let $title := 
                (:if the div has a header:)
                if ($div/tei:head) 
                then
                    concat(
                        if ($n) then concat($n, ': ') else ''
                        ,
                        string-join(
                            for $node in $div/tei:head/node() 
                            return data($node)
                        , ' ')
                    )
                else
                    let $type := $div/@type
                    let $data := toc:generate-title($div//text(), 0)
                    return
                        (:otherwise, take part of the text itself:)
                        if (string-length($data) gt 0) 
                        then
                            concat(
                                if ($type) 
                                then concat('[', $type/string(), '] ') 
                                else ''
                            , substring($data, 1, 25), '…') 
                        else concat('[', $type/string(), ']')
            return $title
        case element(tei:titlePage) return
            tei-to-html:titlePage($div, <options/>)
        default return
            ()
};

declare %private function toc:generate-title($nodes as text()*, $length as xs:int) {
    if ($nodes) then
        let $text := head($nodes)
        return
            if ($length + string-length($text) > 25) then
                (substring($text, 1, 25 - $length) || "…")
            else
                ($text || toc:generate-title(tail($nodes), $length + string-length($text)))
    else
        ()
};