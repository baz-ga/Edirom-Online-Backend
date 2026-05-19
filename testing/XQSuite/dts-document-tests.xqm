xquery version "3.1";

module namespace ddt = "http://www.edirom.de/xquery/xqsuite/dts-document-tests";

import module namespace dts-document = "http://www.edirom.de/api/dts-document" at "xmldb:exist:///db/apps/Edirom-Online-Backend/data/xqm/dts-document.xqm";

declare namespace dts="https://w3id.org/dts/api#";
declare namespace mei="http://www.music-encoding.org/ns/mei";
declare namespace test="http://exist-db.org/xquery/xqsuite";


declare
    %test:args(
        "<mdiv xmlns='http://www.music-encoding.org/ns/mei' xml:id='selection'/>",
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0' xml:id='root'><meiHead><fileDesc/></meiHead><music><body/></music></mei>"
    )
    %test:assertEquals("5.0.0")
    function ddt:test-wrapMEISelection-copies-meiversion(
        $selection as element(),
        $documentRoot as element()
    ) as xs:string {
        let $result := dts-document:wrapMEISelection($selection, document { $documentRoot })
        return string($result/@meiversion)
};

declare
    %test:args(
        "<mdiv xmlns='http://www.music-encoding.org/ns/mei' xml:id='selection'/>",
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0'><meiHead><fileDesc/></meiHead><music><body/></music></mei>"
    )
    %test:assertTrue
    function ddt:test-wrapMEISelection-preserves-meiHead(
        $selection as element(),
        $documentRoot as element()
    ) as xs:boolean {
        let $result := dts-document:wrapMEISelection($selection, document { $documentRoot })
        return exists($result/mei:meiHead/mei:fileDesc)
};

declare
    %test:args(
        "<mdiv xmlns='http://www.music-encoding.org/ns/mei' xml:id='selection'><score/></mdiv>",
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0'><meiHead/><music><body/></music></mei>"
    )
    %test:assertTrue
    function ddt:test-wrapMEISelection-inserts-selection-in-dts-wrapper(
        $selection as element(),
        $documentRoot as element()
    ) as xs:boolean {
        let $result := dts-document:wrapMEISelection($selection, document { $documentRoot })
        return exists($result/mei:music/mei:body/dts:wrapper/mei:mdiv[@xml:id = "selection"]/mei:score)
};

declare
    %test:assertTrue
    function ddt:test-wrapMEISelection-inserts-multiple-mdivs() as xs:boolean {
        let $selection := (
            <mdiv xmlns="http://www.music-encoding.org/ns/mei" xml:id="selection-1"><score/></mdiv>,
            <mdiv xmlns="http://www.music-encoding.org/ns/mei" xml:id="selection-2"><score/></mdiv>
        )
        let $documentRoot := <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0"><meiHead/><music><body/></music></mei>
        let $result := dts-document:wrapMEISelection($selection, document { $documentRoot })
        return
            count($result//dts:wrapper/mei:mdiv) = 2
            and exists($result//dts:wrapper/mei:mdiv[@xml:id = "selection-1"]/mei:score)
            and exists($result//dts:wrapper/mei:mdiv[@xml:id = "selection-2"]/mei:score)
};

declare
    %test:args(
        "<mdiv xmlns='http://www.music-encoding.org/ns/mei' xml:id='selection'/>",
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0'><meiHead/><music><body/></music></mei>"
    )
    %test:assertEquals("http://www.w3.org/1999/xlink")
    function ddt:test-wrapMEISelection-declares-xlink-namespace(
        $selection as element(),
        $documentRoot as element()
    ) as xs:string {
        let $result := dts-document:wrapMEISelection($selection, document { $documentRoot })
        return namespace-uri-for-prefix("xlink", $result)
};

declare
    %test:args("<section xmlns='http://www.music-encoding.org/ns/mei' xml:id='selection'/>")
    %test:assertError("errors:InvalidParametersError")
    function ddt:test-wrapMEISelection-rejects-unsupported-selection(
        $selection as element()
    ) as node()? {
        let $documentRoot := <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0"><meiHead/><music><body/></music></mei>
        return dts-document:wrapMEISelection($selection, document { $documentRoot })
};

declare
    %test:assertEquals("selection-2")
    function ddt:test-MEISelect-selects-ref-in-musicStructure-tree() as xs:string {
        let $documentRoot :=
            <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                <meiHead/>
                <music>
                    <body>
                        <mdiv xml:id="selection-1"/>
                        <mdiv xml:id="selection-2"/>
                    </body>
                </music>
            </mei>
        let $result := dts-document:MEISelect(document { $documentRoot }, "selection-2", (), (), "musicStructure")
        return string($result//dts:wrapper/mei:mdiv/@xml:id)
};

declare
    %test:assertEquals("selection-1", "selection-2", "selection-3")
    function ddt:test-MEISelect-selects-start-end-range() as xs:string* {
        let $documentRoot :=
            <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                <meiHead/>
                <music>
                    <body>
                        <mdiv xml:id="selection-1"/>
                        <mdiv xml:id="selection-2"/>
                        <mdiv xml:id="selection-3"/>
                    </body>
                </music>
            </mei>
        let $result := dts-document:MEISelect(document { $documentRoot }, (), "selection-1", "selection-3", "musicStructure")
        return
            for $mdiv in $result//dts:wrapper/mei:mdiv
            return string($mdiv/@xml:id)
};

declare
    %test:assertError("errors:NotFoundError")
    function ddt:test-MEISelect-errors-when-selection-not-found() as node()* {
        let $documentRoot :=
            <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                <meiHead/>
                <music><body><mdiv xml:id="selection-1"/></body></music>
            </mei>
        return dts-document:MEISelect(document { $documentRoot }, "missing", (), (), "musicStructure")
};

declare
    %test:args("", "mei")                         %test:assertTrue
    %test:args("application/xml", "mei")          %test:assertTrue
    %test:args("text/xml", "mei")                 %test:assertTrue
    %test:args("application/mei+xml", "mei")      %test:assertTrue
    %test:args("application/tei+xml", "mei")      %test:assertFalse
    %test:args("application/json", "edirom")      %test:assertFalse
    %test:args("application/xml", "unknown")      %test:assertFalse
    function ddt:test-isMediaTypeCompatible($mediaType as xs:string?, $namespace as xs:string) as xs:boolean {
        dts-document:isMediaTypeCompatible($mediaType, $namespace)
};

declare
    (: Valid requests :)
    (: retrieve full mei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref") %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei[@xml:id='test-mei-score']")
    (: retrieve a specific mdiv by ref :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref", "test-mdiv-1")
    %test:arg("start") %test:arg("end")
    %test:arg("tree", "musicStructure")
    %test:arg("mediaType", "application/xml")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}mdiv[@xml:id='test-mdiv-1']")
    (: retrieve a range of mdivs by start and end :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref")
    %test:arg("start", "test-mdiv-1")
    %test:arg("end", "test-mdiv-2")
    %test:arg("tree", "musicStructure")
    %test:arg("mediaType", "application/xml")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}mdiv[@xml:id='test-mdiv-1']")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}mdiv[@xml:id='test-mdiv-2']")
    (: retrieve a specific surface by ref :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-facsimile.xml")
    %test:arg("ref", "facsimile-2001002")
    %test:arg("start") %test:arg("end")
    %test:arg("tree", "paginationStructure")
    %test:arg("mediaType", "application/xml")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}surface[@xml:id='facsimile-2001002']")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}measure")
    (: retrieve a specific zone by ref :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-facsimile.xml")
    %test:arg("ref", "zone_bar-2001")
    %test:arg("start") %test:arg("end")
    %test:arg("tree", "paginationStructure")
    %test:arg("mediaType", "application/xml")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}zone[@xml:id='zone_bar-2001']")
    (: retrieve meiHead by ref :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref", "meiHead")
    %test:arg("start") %test:arg("end")
    %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}meiHead")
    (: retrieve meiHead by ref as html :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref", "meiHead")
    %test:arg("start") %test:arg("end")
    %test:arg("tree")
    %test:arg("mediaType", "text/html")
    %test:assertXPath("/Q{http://www.w3.org/1999/xhtml}div[@class='meiHead']") (: TODO check this condition :)
    (: retrieve full tei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref") %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:assertXPath("/Q{http://www.tei-c.org/ns/1.0}TEI[@xml:id='test-tei-document']")
    (: retrieve tei div :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref", "test-div-1")
    %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:assertXPath("/Q{http://www.tei-c.org/ns/1.0}TEI[@xml:id='test-tei-document']//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.tei-c.org/ns/1.0}div[@xml:id='test-div-1']")
    (: retrieve range of tei divs :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref")
    %test:arg("start", "test-div-2")
    %test:arg("end", "test-div-3")
    %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:assertXPath("/Q{http://www.tei-c.org/ns/1.0}TEI[@xml:id='test-tei-document']//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.tei-c.org/ns/1.0}div[@xml:id='test-div-2']")
    %test:assertXPath("/Q{http://www.tei-c.org/ns/1.0}TEI[@xml:id='test-tei-document']//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.tei-c.org/ns/1.0}div[@xml:id='test-div-3']")
    (: retrieve teiHead by ref :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref", "teiHead")
    %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:assertXPath("/Q{http://www.tei-c.org/ns/1.0}TEI[@xml:id='test-tei-document']//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.tei-c.org/ns/1.0}teiHead")
    (: retrieve teiHead by ref as html :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref", "teiHead")
    %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "text/html")
    %test:assertXPath("/Q{http://www.w3.org/1999/xhtml}div[@class='teiHead']") (: TODO check this condition :)
    (: get the help by resource=help_en :)
    (: TODO: ideally help should be processed like any other tei document :)
    %test:arg("resource", "help_en")
    %test:arg("ref") %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "text/html")
    %test:assertXPath("//Q{http://www.w3.org/1999/xhtml}div[@class='titlePage']")
    (: get the help by URI :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/help/help_en.xml")
    %test:arg("ref") %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "text/html")
    %test:assertXPath("//Q{http://www.w3.org/1999/xhtml}div[@class='titlePage']")
    (: Errors :)
    (: ask both for ref and start/end mei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref", "test-mdiv-1")
    %test:arg("start", "test-mdiv-1")
    %test:arg("end", "test-mdiv-2")
    %test:arg("tree", "musicStructure")
    %test:arg("mediaType", "application/xml")
    %test:assertError("errors:InvalidParametersError")
    (: ask both for ref and start/end tei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref", "test-div-1")
    %test:arg("start", "test-div-1")
    %test:arg("end", "test-div-2")
    %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:assertError("errors:InvalidParametersError")
    (: ask for start without end mei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref")
    %test:arg("start", "test-mdiv-1")
    %test:arg("end")
    %test:arg("tree", "musicStructure")
    %test:arg("mediaType", "application/xml")
    %test:assertError("errors:InvalidParametersError")
    (: ask for start without end tei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref")
    %test:arg("start", "test-div-1")
    %test:arg("end")
    %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:assertError("errors:InvalidParametersError")
    function ddt:test-document(
        $resource as xs:string,
        $ref as xs:string?,
        $start as xs:string?,
        $end as xs:string?,
        $tree as xs:string?,
        $mediaType as xs:string?
    ) as document-node() { 
        dts-document:document($resource, $ref, $start, $end, $tree, $mediaType) 
};

(: TODO tests with json media type :)
