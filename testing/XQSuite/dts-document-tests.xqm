xquery version "3.1";

module namespace ddt = "http://www.edirom.de/xquery/xqsuite/dts-document-tests";

import module namespace dts-document = "http://www.edirom.de/api/dts-document" at "xmldb:exist:///db/apps/Edirom-Online-Backend/data/xqm/dts-document.xqm";

declare namespace dts="https://w3id.org/dts/api#";
declare namespace mei="http://www.music-encoding.org/ns/mei";
declare namespace test="http://exist-db.org/xquery/xqsuite";

declare function ddt:citationTree(
    $tree as xs:string?
) as element(citeStructure)* {
    <refsDecl xmlns:mei="http://www.music-encoding.org/ns/mei">
        <citeStructure xml:id="musicStructure"
                        unit="Movement"
                        match="mei:mdiv"
                        use="@xml:id">
            <citeStructure unit="Measure"
                            match="mei:measure"
                            use="@xml:id"/>
        </citeStructure>
        <citeStructure xml:id="paginationStructure"
                        unit="Surface"
                        match="mei:surface"
                        use="@xml:id">
            <citeStructure unit="Zone"
                            match="mei:zone"
                            use="@xml:id"/>
        </citeStructure>
    </refsDecl>/citeStructure[
        not($tree) or @xml:id = $tree
    ]
};

declare
    %test:args(
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0' xml:id='root'><meiHead><fileDesc/></meiHead><music><body><mdiv xml:id='selection'/></body></music></mei>"
    )
    %test:assertEquals("5.0.0")
    function ddt:test-wrapSelection-copies-meiversion(
        $documentRoot as element()
    ) as xs:string {
        let $document := document { $documentRoot }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return string($result/@meiversion)
};

declare
    %test:args(
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0'><meiHead><fileDesc/></meiHead><music><body><mdiv xml:id='selection'/></body></music></mei>"
    )
    %test:assertTrue
    function ddt:test-wrapSelection-preserves-meiHead(
        $documentRoot as element()
    ) as xs:boolean {
        let $document := document { $documentRoot }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return
            exists($result/mei:meiHead/mei:fileDesc)
            and empty($result//dts:wrapper/mei:meiHead)
};

declare
    %test:args(
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0'><meiHead/><music><body><mdiv xml:id='selection'><score/></mdiv></body></music></mei>"
    )
    %test:assertTrue
    function ddt:test-wrapSelection-inserts-selection-in-dts-wrapper(
        $documentRoot as element()
    ) as xs:boolean {
        let $document := document { $documentRoot }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return exists($result/mei:music/mei:body/dts:wrapper/mei:mdiv[@xml:id = "selection"]/mei:score)
};

declare
    %test:assertTrue
    function ddt:test-wrapSelection-inserts-multiple-mdivs() as xs:boolean {
        let $document :=
            document {
                <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                    <meiHead/>
                    <music>
                        <body>
                            <mdiv xml:id="selection-1"><score/></mdiv>
                            <mdiv xml:id="selection-2"><score/></mdiv>
                        </body>
                    </music>
                </mei>
            }
        let $result := dts-document:wrapSelection(($document/id("selection-1"), $document/id("selection-2")), $document)
        return
            count($result//dts:wrapper/mei:mdiv) = 2
            and exists($result//dts:wrapper/mei:mdiv[@xml:id = "selection-1"]/mei:score)
            and exists($result//dts:wrapper/mei:mdiv[@xml:id = "selection-2"]/mei:score)
};

declare
    %test:args(
        "<mei xmlns='http://www.music-encoding.org/ns/mei' xmlns:xlink='http://www.w3.org/1999/xlink' meiversion='5.0.0'><meiHead/><music><body><mdiv xml:id='selection'/></body></music></mei>"
    )
    %test:assertEquals("http://www.w3.org/1999/xlink")
    function ddt:test-wrapSelection-declares-xlink-namespace(
        $documentRoot as element()
    ) as xs:string {
        let $document := document { $documentRoot }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return namespace-uri-for-prefix("xlink", $result)
};

declare
    %test:assertTrue
    function ddt:test-wrapSelection-wraps-any-mei-selection() as xs:boolean {
        let $document :=
            document {
                <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                    <meiHead/>
                    <music><body><mdiv><score><section xml:id="selection"/></score></mdiv></body></music>
                </mei>
            }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return exists($result/mei:music/mei:body/mei:mdiv/mei:score/dts:wrapper/mei:section[@xml:id = "selection"])
};

declare
    %test:assertTrue
    function ddt:test-wrapSelection-prunes-unselected-sibling-mdivs() as xs:boolean {
        let $document :=
            document {
                <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                    <meiHead/>
                    <music>
                        <body>
                            <mdiv xml:id="selection"/>
                            <mdiv xml:id="skipped"/>
                        </body>
                    </music>
                </mei>
            }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return
            exists($result/mei:music/mei:body/dts:wrapper/mei:mdiv[@xml:id = "selection"])
            and empty($result//mei:mdiv[@xml:id = "skipped"])
};

declare
    %test:assertTrue
    function ddt:test-wrapSelection-preserves-surface-ancestor-and-preceding-graphic-for-zone() as xs:boolean {
        let $document :=
            document {
                <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                    <meiHead/>
                    <music>
                        <facsimile>
                            <surface xml:id="surface">
                                <graphic xml:id="graphic"/>
                                <zone xml:id="selection"/>
                                <zone xml:id="skipped"/>
                            </surface>
                        </facsimile>
                    </music>
                </mei>
            }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return
            exists($result/mei:music/mei:facsimile/mei:surface[@xml:id = "surface"]/dts:wrapper/mei:zone[@xml:id = "selection"])
            and exists($result/mei:music/mei:facsimile/mei:surface[@xml:id = "surface"]/mei:graphic[@xml:id = "graphic"])
            and empty($result//mei:zone[@xml:id = "skipped"])
};

declare
    %test:assertTrue
    function ddt:test-wrapSelection-preserves-measure-ancestor-structure() as xs:boolean {
        let $document :=
            document {
                <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                    <meiHead/>
                    <music>
                        <body>
                            <mdiv>
                                <score>
                                    <section>
                                        <measure xml:id="selection"/>
                                        <measure xml:id="skipped"/>
                                    </section>
                                </score>
                            </mdiv>
                        </body>
                    </music>
                </mei>
            }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return
            exists($result/mei:music/mei:body/mei:mdiv/mei:score/mei:section/dts:wrapper/mei:measure[@xml:id = "selection"])
            and empty($result//mei:measure[@xml:id = "skipped"])
};

declare
    %test:assertTrue
    function ddt:test-wrapSelection-preserves-configured-preceding-sibling() as xs:boolean {
        let $document :=
            document {
                <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                    <meiHead/>
                    <music>
                        <body>
                            <mdiv>
                                <score>
                                    <scoreDef xml:id="preceding-scoreDef">
                                        <staffGrp>
                                            <staffDef n="1"/>
                                        </staffGrp>
                                    </scoreDef>
                                    <section>
                                        <measure xml:id="selection"/>
                                    </section>
                                    <scoreDef xml:id="following-scoreDef"/>
                                </score>
                            </mdiv>
                        </body>
                    </music>
                </mei>
            }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return
            exists($result//mei:scoreDef[@xml:id = "preceding-scoreDef"]/mei:staffGrp/mei:staffDef)
            and empty($result//mei:scoreDef[@xml:id = "following-scoreDef"])
};

declare
    %test:assertTrue
    function ddt:test-wrapSelection-includes-forward-facs-reference() as xs:boolean {
        let $document :=
            document {
                <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                    <meiHead/>
                    <music>
                        <facsimile>
                            <surface xml:id="surface">
                                <zone xml:id="referenced-zone"/>
                                <zone xml:id="skipped-zone"/>
                            </surface>
                        </facsimile>
                        <body>
                            <mdiv>
                                <score>
                                    <section>
                                        <measure facs="#referenced-zone" xml:id="selection"/>
                                    </section>
                                </score>
                            </mdiv>
                        </body>
                    </music>
                </mei>
            }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return
            exists($result//dts:wrapper/mei:measure[@xml:id = "selection"])
            and exists($result/mei:music/mei:facsimile/mei:surface[@xml:id = "surface"]/mei:zone[@xml:id = "referenced-zone"])
            and empty($result//mei:zone[@xml:id = "skipped-zone"])
};

declare
    %test:assertTrue
    function ddt:test-wrapSelection-preserves-configured-preceding-sibling-for-referenced-zone() as xs:boolean {
        let $document :=
            document {
                <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                    <meiHead/>
                    <music>
                        <facsimile>
                            <surface xml:id="surface">
                                <graphic xml:id="graphic"/>
                                <zone xml:id="referenced-zone"/>
                                <zone xml:id="skipped-zone"/>
                            </surface>
                        </facsimile>
                        <body>
                            <mdiv>
                                <score>
                                    <section>
                                        <measure facs="#referenced-zone" xml:id="selection"/>
                                    </section>
                                </score>
                            </mdiv>
                        </body>
                    </music>
                </mei>
            }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return
            exists($result//dts:wrapper/mei:measure[@xml:id = "selection"])
            and exists($result/mei:music/mei:facsimile/mei:surface/mei:graphic[@xml:id = "graphic"])
            and empty($result//mei:zone[@xml:id = "skipped-zone"])
};

declare
    %test:assertTrue
    function ddt:test-wrapSelection-ignores-non-facs-reference-attributes() as xs:boolean {
        let $document :=
            document {
                <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                    <meiHead/>
                    <music>
                        <facsimile>
                            <surface xml:id="surface">
                                <zone xml:id="target-zone"/>
                            </surface>
                        </facsimile>
                        <body>
                            <mdiv>
                                <score>
                                    <section>
                                        <measure corresp="#target-zone" xml:id="selection"/>
                                    </section>
                                </score>
                            </mdiv>
                        </body>
                    </music>
                </mei>
            }
        let $result := dts-document:wrapSelection($document/id("selection"), $document)
        return
            exists($result//dts:wrapper/mei:measure[@xml:id = "selection"])
            and empty($result//mei:zone[@xml:id = "target-zone"])
};

declare
    %test:assertEquals("selection-2")
    function ddt:test-selectElementOrRange-selects-ref-in-musicStructure-tree() as xs:string {
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
        let $result := dts-document:selectElementOrRange(document { $documentRoot }, "selection-2", (), (), ddt:citationTree("musicStructure"))
        return string($result//dts:wrapper/mei:mdiv/@xml:id)
};

declare
    %test:assertEquals("selection-1", "selection-2", "selection-3")
    function ddt:test-selectElementOrRange-selects-start-end-range() as xs:string* {
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
        let $result := dts-document:selectElementOrRange(document { $documentRoot }, (), "selection-1", "selection-3", ddt:citationTree("musicStructure"))
        return
            for $mdiv in $result//dts:wrapper/mei:mdiv
            return string($mdiv/@xml:id)
};

declare
    %test:assertError("errors:NotFoundError")
    function ddt:test-selectElementOrRange-errors-when-selection-not-found() as node()* {
        let $documentRoot :=
            <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0">
                <meiHead/>
                <music><body><mdiv xml:id="selection-1"/></body></music>
            </mei>
        return dts-document:selectElementOrRange(document { $documentRoot }, "missing", (), (), ddt:citationTree("musicStructure"))
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
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei[@xml:id='test-mei-score']")
    (: retrieve a specific mdiv by ref :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref", "test-mdiv-1")
    %test:arg("start") %test:arg("end")
    %test:arg("tree", "musicStructure")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang", "de")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}mdiv[@xml:id='test-mdiv-1']")
    (: retrieve a range of mdivs by start and end :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref")
    %test:arg("start", "test-mdiv-1")
    %test:arg("end", "test-mdiv-2")
    %test:arg("tree", "musicStructure")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}mdiv[@xml:id='test-mdiv-1']")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}mdiv[@xml:id='test-mdiv-2']")
    (: retrieve a specific surface by ref :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-facsimile.xml")
    %test:arg("ref", "facsimile-2001002")
    %test:arg("start") %test:arg("end")
    %test:arg("tree", "paginationStructure")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}surface[@xml:id='facsimile-2001002']")
    (:retrieve a range of surfaces by start and end :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-facsimile.xml")
    %test:arg("ref")
    %test:arg("start", "facsimile-2001002")
    %test:arg("end", "facsimile-2001004")
    %test:arg("tree", "paginationStructure")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}surface[@xml:id='facsimile-2001002']")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}surface[@xml:id='facsimile-2001003']")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}surface[@xml:id='facsimile-2001004']")
    (: retrieve a specific zone by ref :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-facsimile.xml")
    %test:arg("ref", "zone_bar-2001")
    %test:arg("start") %test:arg("end")
    %test:arg("tree", "paginationStructure")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}zone[@xml:id='zone_bar-2001']")
    (: retrieve a range of zones by start and end :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-facsimile.xml")
    %test:arg("ref")
    %test:arg("start", "zone_bar-20013")
    %test:arg("end", "zone_bar-20015")
    %test:arg("tree", "paginationStructure")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}zone[@xml:id='zone_bar-20013']")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}zone[@xml:id='zone_bar-20014']")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}zone[@xml:id='zone_bar-20015']")
    (: retrieve meiHead by ref :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref", "meiHead")
    %test:arg("start") %test:arg("end")
    %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.music-encoding.org/ns/mei}mei//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.music-encoding.org/ns/mei}meiHead")
    (: retrieve meiHead by ref as html :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref", "meiHead")
    %test:arg("start") %test:arg("end")
    %test:arg("tree")
    %test:arg("mediaType", "text/html")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.w3.org/1999/xhtml}div[@class='meiHead']") (: TODO check this condition :)
    (: retrieve full tei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref") %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.tei-c.org/ns/1.0}TEI[@xml:id='test-tei-document']")
    (: retrieve tei div :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref", "test-div-1")
    %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.tei-c.org/ns/1.0}TEI[@xml:id='test-tei-document']//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.tei-c.org/ns/1.0}div[@xml:id='test-div-1']")
    (: retrieve range of tei divs :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref")
    %test:arg("start", "test-div-2")
    %test:arg("end", "test-div-3")
    %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.tei-c.org/ns/1.0}TEI[@xml:id='test-tei-document']//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.tei-c.org/ns/1.0}div[@xml:id='test-div-2']")
    %test:assertXPath("/Q{http://www.tei-c.org/ns/1.0}TEI[@xml:id='test-tei-document']//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.tei-c.org/ns/1.0}div[@xml:id='test-div-3']")
    (: retrieve teiHeader by ref :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref", "teiHeader")
    %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertXPath("/Q{http://www.tei-c.org/ns/1.0}TEI[@xml:id='test-tei-document']//Q{https://w3id.org/dts/api#}wrapper/Q{http://www.tei-c.org/ns/1.0}teiHeader")
    (: retrieve teiHeader by ref as html :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref", "teiHeader")
    %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "text/html")
    %test:arg("lang")
    %test:assertXPath("//Q{http://www.w3.org/1999/xhtml}h1") (: TODO check this condition :)
    (: get the help by resource=help :)
    (: TODO: ideally help should be processed like any other tei document :)
    %test:arg("resource", "help_en")
    %test:arg("ref") %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "text/html")
    %test:arg("lang", "en")
    %test:assertXPath("//Q{http://www.w3.org/1999/xhtml}div[@class='titlePage']")
    (: get the help by URI :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/help/help_en.xml")
    %test:arg("ref") %test:arg("start") %test:arg("end") %test:arg("tree")
    %test:arg("mediaType", "text/html")
    %test:arg("lang")
    %test:assertXPath("//Q{http://www.w3.org/1999/xhtml}div[@class='titlePage']")
    (: Errors :)
    (: ask both for ref and start/end mei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref", "test-mdiv-1")
    %test:arg("start", "test-mdiv-1")
    %test:arg("end", "test-mdiv-2")
    %test:arg("tree", "musicStructure")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertError("errors:InvalidParametersError")
    (: ask both for ref and start/end tei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref", "test-div-1")
    %test:arg("start", "test-div-1")
    %test:arg("end", "test-div-2")
    %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertError("errors:InvalidParametersError")
    (: ask for start without end mei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref")
    %test:arg("start", "test-mdiv-1")
    %test:arg("end")
    %test:arg("tree", "musicStructure")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertError("errors:InvalidParametersError")
    (: ask for start without end tei :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref")
    %test:arg("start", "test-div-1")
    %test:arg("end")
    %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertError("errors:InvalidParametersError")
    (: ask for an mei element that is not in the tree and not in the always-included meiHead :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/mei-score.xml")
    %test:arg("ref", "body")
    %test:arg("start") %test:arg("end")
    %test:arg("tree", "musicStructure")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertError("errors:InvalidParametersError")
    (: ask for a tei element that is not in the tree and not in the always-included teiHead :)
    %test:arg("resource", "xmldb:exist:///db/apps/Edirom-Online-Backend/testing/XQSuite/data/tei-document.xml")
    %test:arg("ref", "text")
    %test:arg("start") %test:arg("end")
    %test:arg("tree")
    %test:arg("mediaType", "application/xml")
    %test:arg("lang")
    %test:assertError("errors:InvalidParametersError")
    function ddt:test-document(
        $resource as xs:string,
        $ref as xs:string?,
        $start as xs:string?,
        $end as xs:string?,
        $tree as xs:string?,
        $mediaType as xs:string?,
        $lang as xs:string?
    ) as document-node() { 
        let $html-parameters := map {
            "lang": if ($lang) then $lang else "de",
            "idPrefix": ""
        }
        return
            dts-document:document($resource, $ref, $start, $end, $tree, $mediaType, $html-parameters)
};

(: TODO tests with json media type :)
