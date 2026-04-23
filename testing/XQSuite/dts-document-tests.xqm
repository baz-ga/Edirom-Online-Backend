xquery version "3.1";

module namespace ddt = "http://www.edirom.de/xquery/xqsuite/dts-document-tests";

import module namespace dts-document = "http://www.edirom.de/api/dts-document" at "xmldb:exist:///db/apps/Edirom-Online-Backend/data/xqm/dts-document.xqm";

declare namespace mei="http://www.music-encoding.org/ns/mei";
declare namespace test="http://exist-db.org/xquery/xqsuite";


declare
    %test:args(
        "<mdiv xmlns='http://www.music-encoding.org/ns/mei' xml:id='selection'/>",
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0' xml:id='root'><meiHead><fileDesc/></meiHead><music><body/></music></mei>"
    )
    %test:assertEquals("5.0.0", "root")
    function ddt:test-createMEIOutput-copies-root-attributes(
        $selection as element(),
        $documentRoot as element()
    ) as xs:string* {
        let $result := dts-document:createMEIOutput($selection, "mei", document { $documentRoot })
        return (
            string($result/@meiversion),
            string($result/@xml:id)
        )
};

(:)
declare
    %test:args(
        "<mdiv xmlns='http://www.music-encoding.org/ns/mei' xml:id='selection'/>",
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0'><meiHead><fileDesc/></meiHead><music><body/></music></mei>"
    )
    %test:assertTrue
    function ddt:test-createMEIOutput-preserves-meiHead(
        $selection as element(),
        $documentRoot as element()
    ) as xs:boolean {
        let $result := dts-document:createMEIOutput($selection, "mei", document { $documentRoot })
        return exists($result/mei:meiHead/mei:fileDesc)
};
:)

declare
    %test:args(
        "<mdiv xmlns='http://www.music-encoding.org/ns/mei' xml:id='selection'><score/></mdiv>",
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0'><meiHead/><music><body/></music></mei>"
    )
    %test:assertTrue
    function ddt:test-createMEIOutput-inserts-selection(
        $selection as element(),
        $documentRoot as element()
    ) as xs:boolean {
        let $result := dts-document:createMEIOutput($selection, "mei", document { $documentRoot })
        return exists($result//mei:mdiv[@xml:id = "selection"]/mei:score)
};

declare
    %test:assertTrue
    function ddt:test-createMEIOutput-inserts-multiple-mdivs() as xs:boolean {
        let $selection := (
            <mdiv xmlns="http://www.music-encoding.org/ns/mei" xml:id="selection-1"><score/></mdiv>,
            <mdiv xmlns="http://www.music-encoding.org/ns/mei" xml:id="selection-2"><score/></mdiv>
        )
        let $documentRoot := <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0.0"><meiHead/><music><body/></music></mei>
        let $result := dts-document:createMEIOutput($selection, "mei", document { $documentRoot })
        return
            count($result//mei:mdiv) = 2
            and exists($result//mei:mdiv[@xml:id = "selection-1"]/mei:score)
            and exists($result//mei:mdiv[@xml:id = "selection-2"]/mei:score)
};

declare
    %test:args(
        "<mdiv xmlns='http://www.music-encoding.org/ns/mei' xml:id='selection'/>",
        "<mei xmlns='http://www.music-encoding.org/ns/mei' meiversion='5.0.0'><meiHead/><music><body/></music></mei>"
    )
    %test:assertEquals("http://www.w3.org/1999/xlink")
    function ddt:test-createMEIOutput-declares-xlink-namespace(
        $selection as element(),
        $documentRoot as element()
    ) as xs:string {
        let $result := dts-document:createMEIOutput($selection, "mei", document { $documentRoot })
        return namespace-uri-for-prefix("xlink", $result)
};
