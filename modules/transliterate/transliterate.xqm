xquery version "3.0";

module namespace transliterate = "http://sarit.indology.info/ns/transliterate";

import module namespace sarit-slp1 = "http://hra.uni-heidelberg.de/ns/sarit-transliteration";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function transliterate:get-content($div as element()) {
    typeswitch ($div)
        case element(tei:teiHeader) return $div
(:        case element(tei:pb) return ( :)
(:            let $edition := pages:edition($div):)
(:            let $nextPage :=:)
(:                if ($edition) then:)
(:                    $div/following::tei:pb[@ed = $edition][1]:)
(:                else:)
(:                    $div/following::tei:pb[1]:)
(:            let $chunk :=:)
(:                pages:milestone-chunk($div, $nextPage,:)
(:                    if ($nextPage) then:)
(:                        ($div/ancestor::* intersect $nextPage/ancestor::*)[last()]:)
(:                    else:)
(:                        ($div/ancestor::tei:div, $div/ancestor::tei:body)[1]:)
(:                ):)
(:            return:)
(:                $chunk:)
(:        ) :)
        case element(tei:div) return
            if ($div/tei:div)
            then
                let $child := $div/tei:div[1]
                
                return
                        element { node-name($div) } {
                            $div/@*
                            ,
                            if (not($div/@xml:lang))
                            then attribute xml:lang {$div/ancestor::*/@xml:lang[last()]/data(.)}
                            else ()
                            ,
                            ($child/preceding-sibling::*, $child)
                        }
            else
                $div
        default return
            $div
};

declare function transliterate:transliterate-node($node) {
    element {QName("http://www.tei-c.org/ns/1.0", $node/local-name())} {
        $node/@*
        ,    
        for $child-node in $node/node()
        
        return
            if ($child-node instance of element())
            then transliterate:transliterate-node($child-node)
            else 
                if ($child-node instance of comment())
                then comment {$child-node}
                else sarit-slp1:transliterate($child-node, "deva", "roman")
     }
};

declare function transliterate:transliterate-node2($node) {
    element {QName("http://www.tei-c.org/ns/1.0", $node/local-name())} {
        $node/@*
        ,    
        for $child-node in $node/node()
        
        return
            typeswitch($child-node)
                case comment() return $child-node
                case element() return transliterate:transliterate-node2($child-node)
                case text() return
                    let $lang := $child-node/ancestor-or-self::*/@xml:lang
                    let $lang := $lang[last()]
                    
                    return
                        switch($lang) 
                            case 'sa-Latn' return sarit-slp1:transliterate($child-node, "roman", "deva")
                            case 'en' return $child-node
                            default return ()
                default return ()
     }
};

