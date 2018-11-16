xquery version "3.0";

module namespace app = "http://www.tei-c.org/tei-simple/templates";

import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "lib/pages.xql";
import module namespace tei-to-html="http://exist-db.org/xquery/app/tei2html" at "tei2html.xql";
import module namespace metadata = "http://exist-db.org/ns/sarit/metadata/" at "metadata.xqm";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "navigation.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";

import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $app:expand := doc($config:app-root || "/modules/transliteration-rules.xml")//*[@id = "expand"];
declare variable $app:iast-char-repertoire-negation := '[^aābcdḍeĕghḥiïījklḷḹmṁṃnñṅṇoŏprṛṝsśṣtṭuüūvy0-9\s]';
declare variable $app:query-options :=
    <options>
        <default-operator>and</default-operator>
        <leading-wildcard>yes</leading-wildcard>
        <filter-rewrite>yes</filter-rewrite>
        <lowercase-expanded-terms>no</lowercase-expanded-terms>
    </options>
;

declare
    %templates:wrap
function app:check-login($node as node(), $model as map(*)) {
    let $user := request:get-attribute("org.exist.tei-simple.user")
    return
        if ($user) then
            templates:process($node/*[2], $model)
        else
            templates:process($node/*[1], $model)
};

declare
    %templates:wrap
function app:current-user($node as node(), $model as map(*)) {
    request:get-attribute("org.exist.tei-simple.user")
};

declare
    %templates:wrap
function app:show-if-logged-in($node as node(), $model as map(*)) {
    let $user := request:get-attribute("org.exist.tei-simple.user")
    return
        if ($user) then
            templates:process($node/node(), $model)
        else
            ()
};

(:~
 : List documents in data collection
 :)
declare
    %templates:wrap
    %templates:default("order", "title")
function app:list-works($node as node(), $model as map(*), $filter as xs:string?, $browse as xs:string?,
    $order as xs:string) {
    let $cached := session:get-attribute("simple.works")
    let $filtered :=
        if ($filter) then
            let $ordered :=
                for $item in
                    ft:search($config:data-root, $browse || ":" || $filter, ("author", "title"))/search
                let $author := $item/field[@name = "author"]
                order by $author[1], $author[2], $author[3]
                return
                    $item
            for $doc in $ordered
            return
                doc($doc/@uri)/tei:TEI
        else if ($cached and $filter != "") then
            app:order-documents($cached, $order)
        else
            app:order-documents(collection($config:data-root)/tei:TEI, $order)
    return (
        session:set-attribute("simple.works", $filtered),
        session:set-attribute("browse", $browse),
        session:set-attribute("filter", $filter),
        map {
            "all" : $filtered
        }
    )
};

declare function app:order-documents($docs as element()*, $order as xs:string) {
    let $orderFunc :=
        switch ($order)
            case "author" return
                app:work-author#1
            case "lang" return
                app:work-lang#1
            default return
                app:work-title#1
    for $doc in $docs
    order by $orderFunc($doc)
    return
        $doc
};



declare
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function app:browse($node as node(), $model as map(*), $start as xs:int, $per-page as xs:int, $filter as xs:string?) {
    if (empty($model?all) and (empty($filter) or $filter = "")) then
        templates:process($node/*[@class="empty"], $model)
    else
        subsequence($model?all, $start, $per-page) !
            templates:process($node/*[not(@class="empty")], map:new(($model, map { "work": . })))
};

(:template function in view-work.html:)
declare function app:header($node as node(), $model as map(*)) {
    tei-to-html:render(root($model("data"))//tei:teiHeader)
};

declare
    %templates:wrap
function app:short-header($node as node(), $model as map(*)) {
    let $work := $model("work")/ancestor-or-self::tei:TEI
    let $id := util:document-name($work)
    let $view :=
        if (pages:has-pages($work)) then
            "page"
        else
            $config:default-view
    return
        $pm-config:web-transform($work/tei:teiHeader, map {
            "header": "short",
            "doc": $id || "?view=" || $view
        })
};

(:~
 : Create a bootstrap pagination element to navigate through the hits.
 :)
declare
    %templates:default('key', 'hits')
    %templates:default('start', 1)
    %templates:default("per-page", 10)
    %templates:default("min-hits", 0)
    %templates:default("max-pages", 10)
function app:paginate($node as node(), $model as map(*), $key as xs:string, $start as xs:int, $per-page as xs:int, $min-hits as xs:int,
    $max-pages as xs:int) {
    if ($min-hits < 0 or count($model($key)) >= $min-hits) then
        element { node-name($node) } {
            $node/@*,
            let $count := xs:integer(ceiling(count($model($key))) div $per-page) + 1
            let $middle := ($max-pages + 1) idiv 2
            return (
                if ($start = 1) then (
                    <li class="disabled">
                        <a><i class="glyphicon glyphicon-fast-backward"/></a>
                    </li>,
                    <li class="disabled">
                        <a><i class="glyphicon glyphicon-backward"/></a>
                    </li>
                ) else (
                    <li>
                        <a href="?start=1"><i class="glyphicon glyphicon-fast-backward"/></a>
                    </li>,
                    <li>
                        <a href="?start={max( ($start - $per-page, 1 ) ) }"><i class="glyphicon glyphicon-backward"/></a>
                    </li>
                ),
                let $startPage := xs:integer(ceiling($start div $per-page))
                let $lowerBound := max(($startPage - ($max-pages idiv 2), 1))
                let $upperBound := min(($lowerBound + $max-pages - 1, $count))
                let $lowerBound := max(($upperBound - $max-pages + 1, 1))
                for $i in $lowerBound to $upperBound
                return
                    if ($i = ceiling($start div $per-page)) then
                        <li class="active"><a href="?start={max( (($i - 1) * $per-page + 1, 1) )}">{$i}</a></li>
                    else
                        <li><a href="?start={max( (($i - 1) * $per-page + 1, 1)) }">{$i}</a></li>,
                if ($start + $per-page < count($model($key))) then (
                    <li>
                        <a href="?start={$start + $per-page}"><i class="glyphicon glyphicon-forward"/></a>
                    </li>,
                    <li>
                        <a href="?start={max( (($count - 1) * $per-page + 1, 1))}"><i class="glyphicon glyphicon-fast-forward"/></a>
                    </li>
                ) else (
                    <li class="disabled">
                        <a><i class="glyphicon glyphicon-forward"/></a>
                    </li>,
                    <li>
                        <a><i class="glyphicon glyphicon-fast-forward"/></a>
                    </li>
                )
            )
        }
    else
        ()
};

(:~
    Create a span with the number of items in the current search result.
:)
declare
    %templates:wrap
    %templates:default("key", "hitCount")
function app:hit-count($node as node()*, $model as map(*), $key as xs:string) {
    let $value := $model?($key)
    return
        if ($value instance of xs:integer) then
            $value
        else
            count($value)
};

declare 
    %templates:wrap
function app:checkbox($node as node(), $model as map(*), $target-texts as xs:string*) {
    let $id := $model("work")/@xml:id/string()
    return (
        attribute { "value" } {
            $id
        },
        if ($id = $target-texts) then
            attribute checked { "checked" }
        else
            ()
    )
};

declare function app:statistics($node as node(), $model as map(*)) {
        "SARIT currently contains "|| $metadata:metadata/metadata:number-of-xml-works ||" text files (TEI-XML) of " || $metadata:metadata/metadata:size-of-xml-works || " XML (" || $metadata:metadata/metadata:number-of-pdf-pages || " pages in PDF format)."
};

declare function app:work-author($node as node(), $model as map(*)) {
    let $work := $model("work")/ancestor-or-self::tei:TEI
    let $work-commentators := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'commentator']/text()
    let $work-authors := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'base-author']/text()
    let $work-authors := if ($work-authors) then $work-authors else $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author/text()
    let $work-authors := if ($work-commentators) then $work-commentators else $work-authors
    let $work-authors := if ($work-authors) then tei-to-html:serialize-list($work-authors) else ()
    return 
        $work-authors    
};

declare %public function app:work-author($work as element(tei:TEI)?) {
    let $work-commentators := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'commentator']/text()
    let $work-authors := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'base-author']/text()
    let $work-authors := if ($work-authors) then $work-authors else $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author/text()
    let $work-authors := if ($work-commentators) then $work-commentators else $work-authors
    let $work-authors := if ($work-authors) then tei-to-html:serialize-list($work-authors) else ()
    return 
        $work-authors    
};

declare function app:work-lang($node as node(), $model as map(*)) {
    let $work := $model("work")/ancestor-or-self::tei:TEI
    return
        app:work-lang($work)
};

declare function app:work-lang($work as element(tei:TEI)) {
    let $script := $work//tei:text/@xml:lang
    let $script := if ($script eq 'sa-Latn') then 'IAST' else 'Devanagari'
    let $auto-conversion := $work//tei:revisionDesc/tei:change[@type eq 'conversion'][@subtype eq 'automatic'] 
    return 
        concat($script, if ($auto-conversion) then ' (automatically converted)' else '')  
};


(:~
 :
 :)
declare function app:work-title($node as node(), $model as map(*), $type as xs:string?) {
    let $suffix := if ($type) then "." || $type else ()
    let $work := $model("work")/ancestor-or-self::tei:TEI
    let $id := util:document-name($work)
    let $view :=
        if (pages:has-pages($work)) then
            "page"
        else
            $config:default-view
    return
        <a href="{$node/@href}{$id}{$suffix}?view={$view}">{ app:work-title($work) }</a>
};

declare %public function app:work-title($work as element(tei:TEI)?) {
    let $mainTitle :=
        (
            $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type = "main"]/text(),
            $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1]/text()
        )[1]
    let $subTitles := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type = "sub"][@subtype = "commentary"]
    return
        if ($subTitles) then
            string-join(( $mainTitle, ": ", string-join($subTitles, " and ") ))
        else
            $mainTitle
};

declare function app:download-link($node as node(), $model as map(*), $type as xs:string, $doc as xs:string?,
    $source as xs:boolean?) {
    let $file :=
        if ($model?work) then
            replace(util:document-name($model("work")), "^(.*?)\.[^\.]*$", "$1")
        else
            replace($doc, "^(.*)\..*$", "$1")
    let $uuid := util:uuid()
    return
        element { node-name($node) } {
            $node/@*,
            attribute data-token { $uuid },
            attribute href { $node/@href || $file || "." || $type || "?token=" || $uuid || "&amp;cache=no"
                || (if ($source) then "&amp;source=yes" else ())
            },
            $node/node()
        }
};

declare
    %templates:wrap
function app:fix-links($node as node(), $model as map(*)) {
    app:fix-links(templates:process($node/node(), $model))
};

declare function app:fix-links($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(a) | element(link) return
                (: skip links with @data-template attributes; otherwise we can run into duplicate @href errors :)
                if ($node/@data-template) then
                    $node
                else
                    let $href :=
                        replace(
                            $node/@href,
                            "\$app",
                            (request:get-context-path() || substring-after($config:app-root, "/db"))
                        )
                    return
                        element { node-name($node) } {
                            attribute href {$href}, $node/@* except $node/@href, app:fix-links($node/node())
                        }
            case element() return
                element { node-name($node) } {
                    $node/@*, app:fix-links($node/node())
                }
            default return
                $node
};

(: Search :)

declare function app:work-authors($node as node(), $model as map(*)) {
    let $authors := distinct-values(collection($config:data-root)//tei:fileDesc/tei:titleStmt/tei:author)
    let $authors := for $author in $authors order by translate($author, 'ĀŚ', 'AS') return $author
    let $control :=
        <select multiple="multiple" name="work-authors" class="form-control">
            <option value="all" selected="selected">In Texts By Any Author</option>
            {for $author in $authors
            return <option value="{$author}">{$author}</option>
            }
        </select>
    return
        templates:form-control($control, $model)
};

(:~
: Execute the query. The search results are not output immediately. Instead they
: are passed to nested templates through the $model parameter.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @param $node
: @param $model
: @param $query The query string.
: @param $tei-target A sequence of one or more targets within a TEI document, the tei:teiHeader or tei:text.
: @param $work-authors A sequence of the string "all" or of the xml:ids of the documents associated with the selected authors.
: @param $target-texts A sequence of the string "all" or of the xml:ids of the documents selected.

: @return The function returns a map containing the $hits, the $query, and the $query-scope. The search results are output through the nested templates, app:hit-count, app:paginate, and app:show-hits.
:)
(:template function in search.html:)
declare
    %templates:default("tei-target", "tei-text")
    %templates:default("query-scope", "narrow")
    %templates:default("work-authors", "all")
    %templates:default("target-texts", "all")
    %templates:default("bool", "new")
function app:query($node as node()*, $model as map(*), $query as xs:string?, $tei-target as xs:string+, $query-scope as xs:string, $work-authors as xs:string+, $target-texts as xs:string+, $bool as xs:string) as map(*) {
        (:If there is no query string, fill up the map with existing values:)
        if (empty($query))
        then
            let $hits := session:get-attribute("apps.sarit.hits")
            
            return
                map {
                    "hits" : $hits,
                    "hitCount": count($hits),
                    "lucene-query" : session:get-attribute("apps.sarit.lucene-query"),
                    "scope" : $query-scope (:NB: what about the other arguments?:)
                }
        else
            (:Otherwise, perform the query.:)
            let $queries := $query
            
            (:First, which documents to query against has to be found out. Users can either make no selections in the list of documents, passing the value "all", or they can select individual document, passing a sequence of their xml:ids in $target-texts. Users can also select documents based on their authors. If no specific authors are selected, the value "all" is passed in $work-authors, but if selections have been made, a sequence of their xml:ids is passed. :)
            (:$target-texts will either have the value 'all' or contain a sequence of document xml:ids.:)
            let $target-texts :=
                (:("target-texts", "all")("work-authors", "all"):)
                (:If no texts have been selected and no authors have been selected, search in all texts:)
                if ($target-texts = 'all' and $work-authors = 'all')
                then 'all'
                else
                    (:("target-texts", "sequence of document xml:ids")("work-authors", "all"):)
                    (:If one or more texts have been selected, but no authors, search in selected texts:)
                    if ($target-texts != 'all' and $work-authors = 'all')
                    then $target-texts
                    else
                        (:("target-texts", "all")("work-authors", "sequence of document xml:ids"):)
                        (:If no texts, but one or more authors have been selected, search in texts selected by author:)
                        if ($target-texts = 'all' and $work-authors != 'all')
                        then distinct-values(collection($config:data-root)//tei:TEI[tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author = $work-authors]/@xml:id)
                        else
                            (:("target-texts", "sequence of document xml:ids")("work-authors", "sequence of text xml:ids"):)
                            (:If one or more texts and more authors have been selected, search in the union of selected texts and texts selected by authors:)
                            if ($target-texts != 'all' and $work-authors != 'all')
                            then distinct-values(($target-texts, collection($config:data-root)//tei:TEI[tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author = $work-authors]/@xml:id))
                            else ()
            (:After it has been determined which documents to query, we have to find out which document parts are targeted, the query "context". There are two parts, the text element ("tei-text") and the TEI header ("tei-header"). It is possible to select multiple contexts:)
            let $context :=
                (:If all documents have been selected for query, set the context as $config:data-root:)
                if ($target-texts = 'all')
                then
                    (:if there are two tei-targets, set the context below $config:data-root to the common parent of tei-text and tei-header, the document element TEI, otherwise set it to tei-text and tei-header, respectively.:)
                    if (count($tei-target) eq 2)
                    then collection($config:data-root)/tei:TEI
                    else
                        if ($tei-target = 'tei-text')
                        then collection($config:data-root)/tei:TEI/tei:text
                        else
                            if ($tei-target = 'tei-header')
                            then collection($config:data-root)/tei:TEI/tei:teiHeader
                            else ()
                else
                    (:If individual documents have been selected for query, use the sequence of xml:ids in $target-texts to filter the documents below $config:data-root:)
                    if (count($tei-target) eq 2)
                    (:if there are two tei-targets, set the context below $config:data-root to the common parent of tei-text and tei-header, the document element TEI, otherwise set it to tei-text and tei-header, respectively.:)
                    then collection($config:data-root)//tei:TEI[@xml:id = $target-texts]
                    else
                        if ($tei-target = 'tei-text')
                        then collection($config:data-root)//tei:TEI[@xml:id = $target-texts]/tei:text
                        else
                            if ($tei-target = 'tei-header')
                            then collection($config:data-root)//tei:TEI[@xml:id = $target-texts]/tei:teiHeader
                            else ()
            (: Here the actual query commences. :)
            let $hits :=
                (:If the $query-scope is narrow, query the elements immediately below the lowest div in tei:text and the four major element below tei:teiHeader.:)
                if ($query-scope eq 'narrow')
                then
                    for $hit in
                        (:If both tei-text and tei-header is queried.:)
                        if (count($tei-target) eq 2)
                        then
                            (
                            $context//tei:p[ft:query(., $queries, $app:query-options)],
                            $context//tei:head[ft:query(., $queries, $app:query-options)],
                            $context//tei:lg[ft:query(., $queries, $app:query-options)],
                            $context//tei:trailer[ft:query(., $queries, $app:query-options)],
                            $context//tei:note[ft:query(., $queries, $app:query-options)],
                            $context//tei:list[ft:query(., $queries, $app:query-options)],
                            $context//tei:l[not(local-name(./..) eq 'lg')][ft:query(., $queries, $app:query-options)],
                            $context//tei:quote[ft:query(., $queries, $app:query-options)],
                            $context//tei:table[ft:query(., $queries, $app:query-options)],
                            $context//tei:listApp[ft:query(., $queries, $app:query-options)],
                            $context//tei:listBibl[ft:query(., $queries, $app:query-options)],
                            $context//tei:cit[ft:query(., $queries, $app:query-options)],
                            $context//tei:label[ft:query(., $queries, $app:query-options)],
                            $context//tei:encodingDesc[ft:query(., $queries, $app:query-options)],
                            $context//tei:fileDesc[ft:query(., $queries, $app:query-options)],
                            $context//tei:profileDesc[ft:query(., $queries, $app:query-options)],
                            $context//tei:revisionDesc[ft:query(., $queries, $app:query-options)]
                            )
                        else
                            if ($tei-target = 'tei-text')
                            then
                                (
                                $context//tei:p[ft:query(., $queries, $app:query-options)],
                                $context//tei:head[ft:query(., $queries, $app:query-options)],
                                $context//tei:lg[ft:query(., $queries, $app:query-options)],
                                $context//tei:trailer[ft:query(., $queries, $app:query-options)],
                                $context//tei:note[ft:query(., $queries, $app:query-options)],
                                $context//tei:list[ft:query(., $queries, $app:query-options)],
                                $context//tei:l[not(local-name(./..) eq 'lg')][ft:query(., $queries, $app:query-options)],
                                $context//tei:quote[ft:query(., $queries, $app:query-options)],
                                $context//tei:table[ft:query(., $queries, $app:query-options)],
                                $context//tei:listApp[ft:query(., $queries, $app:query-options)],
                                $context//tei:listBibl[ft:query(., $queries, $app:query-options)],
                                $context//tei:cit[ft:query(., $queries, $app:query-options)],
                                $context//tei:label[ft:query(., $queries, $app:query-options)]
                                )
                            else
                                if ($tei-target = 'tei-header')
                                then
                                    (
                                    $context//tei:encodingDesc[ft:query(., $queries, $app:query-options)],
                                    $context//tei:fileDesc[ft:query(., $queries, $app:query-options)],
                                    $context//tei:profileDesc[ft:query(., $queries, $app:query-options)],
                                    $context//tei:revisionDesc[ft:query(., $queries, $app:query-options)]
                                    )
                                else ()
                    order by ft:score($hit) descending
                    return $hit
                (:If the $query-scope is broad, query the lowest div in tei:text and tei:teiHeader.:)
                else
                    for $hit in
                        if (count($tei-target) eq 2)
                        then
                            (
                            $context//tei:div[not(tei:div)][ft:query(., $queries, $app:query-options)],
                            $context/descendant-or-self::tei:teiHeader[ft:query(., $queries, $app:query-options)](:NB: Can divs occur in the header? If so, they have to be removed here5:)
                            )
                        else
                            if ($tei-target = 'tei-text')
                            then
                                (
                                $context//tei:div[not(tei:div)][ft:query(., $queries, $app:query-options)]
                                )
                            else
                                if ($tei-target = 'tei-header')
                                then
                                    $context/descendant-or-self::tei:teiHeader[ft:query(., $queries, $app:query-options)]
                                else ()
                    order by ft:score($hit) descending
                    return $hit

            let $hits :=
                if ($bool eq 'or')
                then session:get-attribute("apps.sarit.hits") union $hits
                else
                    if ($bool eq 'and')
                    then session:get-attribute("apps.sarit.hits") intersect $hits
                    else
                        if ($bool eq 'not')
                        then session:get-attribute("apps.sarit.hits") except $hits
                        else $hits
            (:gather up previous searches for match highlighting.:)
            let $lucene-query :=
                if ($bool eq 'new')
                then $queries
                else
                    if ($bool = ('or', 'and'))
                    then ($queries, session:get-attribute("apps.sarit.lucene-query"))
                    else
                        if ($bool eq 'not')
                        then session:get-attribute("apps.sarit.lucene-query")
                        else ''
    
            let $store := (
                session:set-attribute("apps.sarit.hits", $hits),
                session:set-attribute("apps.sarit.lucene-query", $lucene-query),
                session:set-attribute("apps.sarit.scope", $query-scope),
                session:set-attribute("apps.sarit.bool", $bool)
                )
            
            return
                (: The hits are not returned directly, but processed by the nested templates :)
                map {
                    "hits" : $hits,
                    "hitCount": count($hits),
                    "lucene-query" : $lucene-query
                }
};

declare function app:expand-hits($divs as element()*) {
    let $queries := session:get-attribute("apps.sarit.lucene-query")
                
    for $div in $divs
    let $result := $div[ft:query(., session:get-attribute("apps.sarit.lucene-query"), $app:query-options)]
    
    return util:expand($result, "add-exist-id=all")
};

(:~
    Output the actual search result as a div, using the kwic module to summarize full text matches.
:)
declare
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function app:show-hits($node as node()*, $model as map(*), $start as xs:integer, $per-page as xs:integer, $view as xs:string?) {
    for $hit at $p in subsequence($model("hits"), $start, $per-page)
    let $work := $hit/ancestor::tei:TEI
    let $parent := $hit/ancestor-or-self::tei:div[1]
    let $parent := ($hit/self::tei:body, $hit/ancestor-or-self::tei:div[1])[1]
    let $parent := ($parent, $hit/ancestor-or-self::tei:teiHeader, $hit)[1]
    let $parent-id := util:document-name($parent) || "?root=" || util:node-id($parent)
    let $config := tpu:parse-pi(root($work), $view)
    let $div := app:get-current($config, $parent)
    let $div-id := util:document-name($div) || "?root=" || util:node-id($div)
    (:if the nearest div does not have an xml:id, find the nearest element with an xml:id and use it:)
    (:is this necessary - can't we just use the nearest ancestor?:)
(:    let $div-id := :)
(:        if ($div-id) :)
(:        then $div-id :)
(:        else ($hit/ancestor-or-self::*[@xml:id]/@xml:id)[1]/string():)
    (:if it is not a div, it will not have a head --> at least mention this :)
    let $div-head := if ($parent/tei:head) then $parent/tei:head//text() else "[[Untitled section]]"
    (:TODO: what if the hit is in the header?:)
    let $work-title := app:work-title($work)
    (:the work always has xml:id.:)
    let $work-id := $work/@xml:id/string()
    let $work-id := util:document-name($work)

    let $loc :=
        <tr class="reference">
            <td colspan="3">
                <span class="number">{$start + $p - 1}</span>
                <span class="headings">
                    <a href="{$work-id}">{$work-title}</a>{if ($div-head) then ' / ' else ''}<a href="{$parent-id}&amp;action=search">{$div-head}</a>
                </span>
            </td>
        </tr>
    let $expanded := util:expand($hit, "add-exist-id=all")
    return (
        $loc,
        for $match in subsequence($expanded//exist:match, 1, 5)
        let $matchId := $match/../@exist:id
        let $docLink :=
            if ($config?view = "page") then
                let $edition := config:edition($div)
                let $contextNode := util:node-by-id($div, $matchId)
                let $page := $contextNode/preceding::tei:pb[@ed = $edition][1]
                return
                    util:document-name($work) || "?root=" || util:node-id($page)
            else
                $div-id
        let $link := $docLink || "&amp;action=search&amp;view=" || $config?view || "&amp;" || "#" || $matchId
        let $config := <config width="60" table="yes" link="{$link}"/>

        return kwic:get-summary($expanded, $match, $config)
    )
};

declare %private function app:get-current($config as map(*), $div as element()?) {
    if (empty($div)) then
        ()
    else
        if ($div instance of element(tei:teiHeader)) then
        $div
        else
            if (
                empty($div/preceding-sibling::tei:div)  (: first div in section :)
                and count($div/preceding-sibling::*) < 5 (: less than 5 elements before div :)
                and $div/.. instance of element(tei:div) (: parent is a div :)
            ) then
                nav:get-previous-div($config, $div/..)
            else
                $div
};

(:
declare %private function app:get-current($div as element()?) {
    if (empty($div)) then
        ()
    else
        if ($div instance of element(tei:teiHeader)) then
        $div
        else
            if (
                empty($div/preceding-sibling::tei:div)  :)
(: first div in section :)(:

                and count($div/preceding-sibling::*) < 5 :)
(: less than 5 elements before div :)(:

                and $div/.. instance of element(tei:div) :)
(: parent is a div :)(:

            ) then
                pages:get-previous($div/..)
            else
                $div
};
:)
