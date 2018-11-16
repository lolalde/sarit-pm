xquery version "3.0";

module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config";

(:
import module namespace pm-web="http://www.tei-c.org/tei-simple/models/sarit.odd/web/module" at "../transform/sarit-web-module.xql";
import module namespace pm-print="http://www.tei-c.org/tei-simple/models/sarit.odd/fo/module" at "../transform/sarit-print-module.xql";
import module namespace pm-latex="http://www.tei-c.org/tei-simple/models/sarit.odd/latex/module" at "../transform/sarit-latex-module.xql";
import module namespace pm-epub="http://www.tei-c.org/tei-simple/models/sarit.odd/epub/module" at "../transform/sarit-epub-module.xql";

declare variable $pm-config:web-transform := pm-web:transform#2;
declare variable $pm-config:print-transform := pm-print:transform#2;
declare variable $pm-config:latex-transform := pm-latex:transform#2;
declare variable $pm-config:epub-transform := pm-epub:transform#2;

:)

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace pmu="http://www.tei-c.org/tei-simple/xquery/util";

declare variable $pm-config:web-transform := pm-config:process(?, ?, ?, "web");
declare variable $pm-config:print-transform := pm-config:process(?, ?, ?, "print");
declare variable $pm-config:latex-transform := pm-config:process(?, ?, ?, "latex");
declare variable $pm-config:epub-transform := pm-config:process(?, ?, ?, "epub");

declare function pm-config:process($xml as node()*, $parameters as map(*)?, $odd as xs:string?, $outputMode as xs:string) {
    let $oddName := ($odd, $config:odd)[1]
    return
        pmu:process($config:odd-root || "/" || $oddName, $xml, $config:output-root, $outputMode,
            "../" || $config:output, $config:module-config, $parameters)
};
