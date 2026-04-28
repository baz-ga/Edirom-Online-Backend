xquery version "3.1";

module namespace dts-document = "http://www.edirom.de/api/dts-document";

import module namespace eutil = "http://www.edirom.de/xquery/eutil" at "eutil.xqm";

declare namespace dts = "https://w3id.org/dts/api#";
declare namespace mei = "http://www.music-encoding.org/ns/mei";
declare namespace system = "http://exist-db.org/xquery/system";
declare namespace transform = "http://exist-db.org/xquery/transform";

declare variable $dts-document:INVALID_PARAMETERS := QName("http://www.edirom.de/api/dts-document", "InvalidParametersError");
declare variable $dts-document:UNSUPPORTED_MEDIA_TYPE := QName("http://www.edirom.de/api/dts-document", "UnsupportedMediaTypeError");
declare variable $dts-document:UNSUPPORTED_DOCUMENT_FORMAT := QName("http://www.edirom.de/api/dts-document", "UnsupportedDocumentFormatError");
declare variable $dts-document:NOT_FOUND := QName("http://www.edirom.de/api/dts-document", "NotFoundError");

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

declare function dts-document:isMediaTypeCompatible(
    $mediaType as xs:string?,
    $namespace as xs:string
) as xs:boolean {
    if (not($mediaType)) then
        true()
    else if ($namespace eq "mei") then
        contains($mediaType, "application/xml") or contains($mediaType, "text/xml") or contains($mediaType, "application/mei+xml")
    else if ($namespace eq "tei") then
        contains($mediaType, "application/xml") or contains($mediaType, "text/xml") or contains($mediaType, "application/tei+xml")
    else if ($namespace eq "edirom") then
        contains($mediaType, "application/xml") or contains($mediaType, "text/xml")
    else
        false()
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
        error($dts-document:INVALID_PARAMETERS, "The 'ref' parameter cannot be used together with 'start' or 'end'.")
    else if (($start and not($end)) or ($end and not($start))) then
        error($dts-document:INVALID_PARAMETERS, "Both 'start' and 'end' parameters must be provided together.")
    else
        let $document := doc($resource)/root()
        let $namespace := 
            if ($document) then
                eutil:getNamespace($document/*)
            else
                error($dts-document:NOT_FOUND, "The requested resource was not found.")

        let $mediaTypeCompatible := dts-document:isMediaTypeCompatible($mediaType, $namespace)

        (: TODO maybe do some checks that the ref, start and end make sense :)


        let $output := 
            if (not($mediaTypeCompatible)) then
                error($dts-document:UNSUPPORTED_MEDIA_TYPE, "The requested media type is not compatible with the document format. Media type: " || $mediaType || ", Namespace: " || $namespace)
            else if (not($ref) and not($start) and not($end)) then
                $document
            else if ($namespace eq "mei") then
                let $selection := dts-document:MEISelect($document, $ref, $start, $end, $tree)
                return 
                    if ($selection) then
                        dts-document:createMEIOutput($selection, $document)
                    else
                        error($dts-document:NOT_FOUND, "The specified citable units did not match any element in the document.")
            else
                error($dts-document:UNSUPPORTED_DOCUMENT_FORMAT, "The format of the requested document is not supported. Namespace: " || $namespace )
        
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
