xquery version "3.1";

import module namespace transliterate = "http://sarit.indology.info/ns/transliterate" at "transliterate.xqm";
import module namespace pages = "http://www.tei-c.org/tei-simple/pages" at "../lib/pages.xql";
import module namespace config = "http://www.tei-c.org/tei-simple/config" at "../config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "../pm-config.xql";
import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

let $doc := request:get-parameter("doc", ())
let $root := request:get-parameter("root", ())
let $id := request:get-parameter("id", ())
let $view := request:get-parameter("view", $config:default-view)

let $xml :=
    if ($id)
    then
        let $node := doc($config:app-root || "/" || $doc)/id($id)
        let $div := $node/ancestor-or-self::tei:div[1]
        return
            if (empty($div)) then
                $node/following-sibling::tei:div[1]
            else
                $div
    else
        pages:load-xml($view, $root, $doc)

let $xml := pages:get-content($xml?config, $xml?data)
let $log := console:log($xml)
(: let $xml := transliterate:get-content($xml) :)

return
    if ($xml)
    then
        let $transliterated-xml := transliterate:transliterate-node2($xml)
        let $html := $pm-config:web-transform($transliterated-xml, map { "root": doc($config:app-root || "/" || $doc) }, ())
        
        return
            map {
                "content": serialize($html,
                    <output:serialization-parameters xmlns:output="http://www.w3.org/2010/xslt-xquery-serialization">
                      <output:indent>no</output:indent>
                    </output:serialization-parameters>)
            }
    else
        map { "error": "Not found" }    
