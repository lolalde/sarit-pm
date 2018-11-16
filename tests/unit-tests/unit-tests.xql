xquery version "3.0";

(: 

Test queries in SARIT.

 :)

module namespace sarit="http://sarit.indology.info/exist/xquery";

declare namespace test="http://exist-db.org/xquery/xqsuite";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(: the standard analyzer, should be case insensitive :)
declare variable $sarit:SARIT-tei-namespace :=
    <collection xmlns="http://exist-db.org/collection-config/1.0">
        <index xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <lucene>
        <analyzer class="de.unihd.hra.libs.java.luceneTranscodingAnalyzer.TranscodingAnalyzer"/>
	<text qname="tei:p"/>
        </lucene>
        </index>
	</collection>;

declare variable $sarit:SARIT :=
    <collection xmlns="http://exist-db.org/collection-config/1.0">
        <index xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <lucene>
        <analyzer class="de.unihd.hra.libs.java.luceneTranscodingAnalyzer.TranscodingAnalyzer"/>
	<text qname="p"/>
        </lucene>
        </index>
    </collection>;


declare
    %test:setUp
function sarit:setup() {
	let $testCol := xmldb:create-collection("/db", "sarittests")
	let $confCol := xmldb:create-collection("/db/system/config/db", "sarittests")
	(: let $testdoc := doc("../resources/search/script-search-tests.xml") :)
	let $testdoc :=
	<div>
	<p>यो विरुद्धधर्माध्यासवान् नासावेकः । यथा घटादिरर्थः ।</p>
	<p>yo viruddhadharmādhyāsavān nāsāvekaḥ । yathā ghaṭādirarthaḥ ।</p>
	<p>अन्यथा सति</p>
	<p>anyathā sati</p>
	<p>सा</p>
	<p>sā</p>
	<p>सः</p>
	<p>saḥ</p>
	<p>अष्टकः</p>
	<p>aṣṭakaḥ</p>
	</div>
    return (
        xmldb:store($confCol, "collection.xconf", $sarit:SARIT),
        xmldb:store($testCol, "test.xml", $testdoc)
    )
};

declare
   %test:tearDown
function sarit:tearDown() {
   xmldb:remove("/db/sarittests"),
   xmldb:remove("/db/system/config/db/sarittests")
};



declare %test:assertEquals("Just checking") function local:just-checking() {
    "Just checking"
};

(: standard queries  :)

declare 
%test:args("yo")
%test:assertEquals("<p>यो विरुद्धधर्माध्यासवान् नासावेकः । यथा घटादिरर्थः ।</p>",
	"<p>yo viruddhadharmādhyāsavān nāsāvekaḥ । yathā ghaṭādirarthaḥ ।</p>")
%test:args("yathā")
%test:assertEquals("<p>यो विरुद्धधर्माध्यासवान् नासावेकः । यथा घटादिरर्थः ।</p>",
	"<p>yo viruddhadharmādhyāsavān nāsāvekaḥ । yathā ghaṭādirarthaḥ ।</p>")
%test:args("यथा")
%test:assertEquals("<p>यो विरुद्धधर्माध्यासवान् नासावेकः । यथा घटादिरर्थः ।</p>",
	"<p>yo viruddhadharmādhyāsavān nāsāvekaḥ । yathā ghaṭādirarthaḥ ।</p>")
%test:args("viruddhadharmādhyāsavān")
%test:assertEquals("<p>यो विरुद्धधर्माध्यासवान् नासावेकः । यथा घटादिरर्थः ।</p>",
	"<p>yo viruddhadharmādhyāsavān nāsāvekaḥ । yathā ghaṭādirarthaḥ ।</p>")
function sarit:simple-query($querystring as xs:string) {
	doc("/db/sarittests/test.xml")//p[ft:query(., $querystring)]
};


(: wildcard queries without diacritics :)
(: diacritics here means non-lowercase letter in the SLP1 index  :)

declare 
%test:args("vi*")
%test:assertEquals("<p>यो विरुद्धधर्माध्यासवान् नासावेकः । यथा घटादिरर्थः ।</p>",
	"<p>yo viruddhadharmādhyāsavān nāsāvekaḥ । yathā ghaṭādirarthaḥ ।</p>")
%test:args("ya*")
%test:assertEquals("<p>यो विरुद्धधर्माध्यासवान् नासावेकः । यथा घटादिरर्थः ।</p>",
	"<p>yo viruddhadharmādhyāsavān nāsāvekaḥ । yathā ghaṭādirarthaḥ ।</p>")
%test:args("anya*")
%test:assertEquals("<p>अन्यथा सति</p>",
	"<p>anyathā sati</p>")
function sarit:wildcard-queries-no-diacrictics($querystring as xs:string) {
	doc("/db/sarittests/test.xml")//p[ft:query(., $querystring)]
};

(: wildcard queries with diacritics :)

declare
%test:args("GawA*")
%test:assertEquals("<p>यो विरुद्धधर्माध्यासवान् नासावेकः । यथा घटादिरर्थः ।</p>",
	"<p>yo viruddhadharmādhyāsavān nāsāvekaḥ । yathā ghaṭādirarthaḥ ।</p>")
%test:args("GawA*")
%test:assertEquals("<p>यो विरुद्धधर्माध्यासवान् नासावेकः । यथा घटादिरर्थः ।</p>",
	"<p>yo viruddhadharmādhyāsavān nāsāvekaḥ । yathā ghaṭādirarthaḥ ।</p>")
%test:args("virudDa*")
%test:assertEquals("<p>यो विरुद्धधर्माध्यासवान् नासावेकः । यथा घटादिरर्थः ।</p>",
	"<p>yo viruddhadharmādhyāsavān nāsāvekaḥ । yathā ghaṭādirarthaḥ ।</p>")
function sarit:wildcard-queries-with-diacrictics($querystring as xs:string) {
	doc("/db/sarittests/test.xml")//p[ft:query(., $querystring)]
};


(: confusing things :)

declare

%test:args("sA*")
%test:assertEquals("<p>सा</p>", "<p>sā</p>")
%test:args("azwa*")
%test:assertEquals("<p>अष्टकः</p>", "<p>aṣṭakaḥ</p>")
function sarit:case-confusions($querystring as xs:string) {
	doc("/db/sarittests/test.xml")//p[ft:query(., $querystring)]
};


(: combination queries :)

declare
%test:args("anyathā AND sati")
%test:assertEquals("<p>अन्यथा सति</p>","<p>anyathā sati</p>")
%test:args("अन्यथा AND सति")
%test:assertEquals("<p>अन्यथा सति</p>","<p>anyathā sati</p>")
%test:args("anyaTA AND sati")
%test:assertEquals("<p>अन्यथा सति</p>","<p>anyathā sati</p>")
function sarit:query-lucene-and($querystring as xs:string) {
	doc("/db/sarittests/test.xml")//p[ft:query(., $querystring)]
};
