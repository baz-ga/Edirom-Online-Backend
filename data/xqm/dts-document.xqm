xquery version "3.1";

module namespace dts-document = "http://www.edirom.de/api/dts-document";

import module namespace eutil = "http://www.edirom.de/xquery/eutil" at "eutil.xqm";

declare namespace dts = "https://w3id.org/dts/api#";
declare namespace mei = "http://www.music-encoding.org/ns/mei";
declare namespace system = "http://exist-db.org/xquery/system";
declare namespace transform = "http://exist-db.org/xquery/transform";

declare function dts-document:createMEIOutput(
    $selection as node()*,
    $document as node()
) as node()? {
    element { node-name($document/*) } {
        namespace xlink { "http://www.w3.org/1999/xlink" },
        $document/*/@*,
        (: $document//mei:meiHead, :)
        <dts:wrapper xmlns:dts="https://w3id.org/dts/api#">
            {$selection}
        </dts:wrapper>
    }
};

declare function dts-document:MEISelect(
    $document as node(),
    $ref as xs:string?,
    $start as xs:string?,
    $end as xs:string?,
    $tree as xs:string?
) as node()* {
    if ($tree eq "musicStructure" and $ref) then
        $document/id($ref)
    else if ($tree eq "musicStructure" and $start and $end) then
        (
            $document/id($start),
            $document/id($start)/following-sibling::*[
                . << $document/id($end)
            ],
            $document/id($end)
        )
    else
        ()
};

declare function dts-document:document(
    $resource as xs:string?,
    $ref as xs:string?,
    $start as xs:string?,
    $end as xs:string?,
    $tree as xs:string?,
    $mediaType as xs:string?
) as document-node() {
    if ($ref and ($start or $end)) then
        error(xs:QName("InvalidParameters"), "The 'ref' parameter cannot be used together with 'start' or 'end'.")
    else if (($start and not($end)) or ($end and not($start))) then
        error(xs:QName("InvalidParameters"), "Both 'start' and 'end' parameters must be provided together.")
    else
        let $document := doc($resource)/root()

        let $namespace := eutil:getNamespace($document/*)

        (: TODO maybe do some checks that the ref, start and end make sense :)


        let $output := 
            if (not($ref) and not($start) and not($end)) then
            (: TODO check if the mediaType corresponds to the document type :)
                $document
            else if ($namespace eq "mei") then
                let $selection := dts-document:MEISelect($document, $ref, $start, $end, $tree)
                return dts-document:createMEIOutput($selection, $document)
            else
                error(xs:QName("UnsupportedFormat"), "The provided document format is not supported. Namespace: " || $namespace )
        
        let $base := concat(replace(system:get-module-load-path(), 'embedded-eXist-server', ''), '/../xslt/')
        let $output := transform:transform($output, concat($base, 'edirom_prepareAnnotsForRendering.xsl'), <parameters/>)
            
        return
            document { $output
                (:
                <document>
                    <message>This is a document endpoint.</message>
                    <parameters>
                        <resource>{if (exists($resource)) then $resource else "Not provided"}</resource>
                        <ref>{if (exists($ref)) then $ref else "Not provided"}</ref>
                        <start>{if (exists($start)) then $start else "Not provided"}</start>
                        <end>{if (exists($end)) then $end else "Not provided"}</end>
                        <tree>{if (exists($tree)) then $tree else "Not provided"}</tree>
                        <mediaType>{if (exists($mediaType)) then $mediaType else "Not provided"}</mediaType>
                    </parameters>
                    <result>{if (exists($output)) then $output else "No tree fragment requested"}</result>
                </document>
                :)
            }
};
