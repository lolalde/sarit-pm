xquery version "3.1";

import module namespace transliterate = "http://sarit.indology.info/ns/transliterate" at "transliterate.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

let $data-collection-path := "/apps/sarit-data/data/"
let $document-name := "mahabharata-devanagari"
let $document := doc($data-collection-path || $document-name || ".xml")

let $result-document-path := $data-collection-path || "temp/" || $document-name || "-iast.xml"
(: let $store-result-document := xmldb:store($result-document-path, $document-name || "-iast.xml", $document) :)
let $result-document := doc($result-document-path)

return
    for $node in $result-document//tei:text/tei:body/tei:div[13]/tei:div[position() = (35 to 35)]
    let $processed-node := transliterate:transliterate-node($node)
    
    return update replace $node with $processed-node

 (:
13 - 274 anuzAsana-13-
14 - 118 Azvamedhika-14
15 - 9 mausala-15
16 - 41 AzramavAsika-16-
17 - 3
18 - 6
 tei:div[position() = (1 to 5)]
 (tei:head | tei:p)
 :)