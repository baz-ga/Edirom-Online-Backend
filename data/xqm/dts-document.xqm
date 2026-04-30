xquery version "3.1";
(:
 : For LICENSE-Details please refer to the LICENSE file in the root directory of this repository.
 :)

 (:~
 : This module provides library functions for handling errors
 :
 : @author Francesco Maccarini
 :)
module namespace dts-document = "http://www.edirom.de/api/dts-document";

(: IMPORTS ================================================================= :)

import module namespace eutil = "http://www.edirom.de/xquery/eutil" at "eutil.xqm";
import module namespace errors = "http://www.edirom.de/xquery/errors" at "errors.xqm";

(: NAMESPACE DECLARATIONS ================================================== :)

declare namespace dts = "https://w3id.org/dts/api#";
declare namespace mei = "http://www.music-encoding.org/ns/mei";
declare namespace system = "http://exist-db.org/xquery/system";
declare namespace transform = "http://exist-db.org/xquery/transform";

(: FUNCTION DECLARATIONS =================================================== :)

declare function dts-document:wrapMEISelection(
    $selection as node()*,
    $document as node()
) as node()? {
    if (node-name($selection[1]) eq QName("http://www.music-encoding.org/ns/mei", "mdiv")) then
        <mei xmlns="http://www.music-encoding.org/ns/mei"
            xmlns:xlink="http://www.w3.org/1999/xlink"
            meiversion="{$document//mei:mei/@meiversion}">
            {$document//mei:meiHead}
            <music>
                <facsimile/>
                <body>
                    <dts:wrapper xmlns:dts="https://w3id.org/dts/api#">
                        {$selection}
                    </dts:wrapper>
                </body>
            </music>
        </mei>
    else
        error($errors:INVALID_PARAMETERS, "Selection not implemented. Selected element: " || node-name($selection[1]))
};

declare function dts-document:MEISelect(
    $document as node(),
    $ref as xs:string?,
    $start as xs:string?,
    $end as xs:string?,
    $tree as xs:string?
) as node()* {
    let $selection :=
        if ($tree eq "musicStructure" and $ref) then
            $document/id($ref)
        else if ($tree eq "musicStructure" and $start and $end) then
            let $startNode := $document/id($start)
            let $endNode := $document/id($end)
                return
                    if ($start eq $end) then
                        $startNode
                    else if ($startNode and $endNode and ($startNode << $endNode)) then
                        (
                            $startNode,
                            $startNode/following-sibling::*[
                                . << $endNode
                            ],
                            $endNode
                        )
                    else
                        ()
        else
            ()
    return
        if ($selection) then
            dts-document:wrapMEISelection($selection, $document)
        else
            error($errors:NOT_FOUND, "The specified citable units did not match any element in the document.")
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
        error($errors:INVALID_PARAMETERS, "The 'ref' parameter cannot be used together with 'start' or 'end'.")
    else if (($start and not($end)) or ($end and not($start))) then
        error($errors:INVALID_PARAMETERS, "Both 'start' and 'end' parameters must be provided together.")
    else
        let $document := doc($resource)/root()
        let $namespace := 
            if ($document) then
                eutil:getNamespace($document/*)
            else
                error($errors:NOT_FOUND, "The requested resource was not found.")

        let $mediaTypeCompatible := dts-document:isMediaTypeCompatible($mediaType, $namespace)

        (: TODO maybe do some checks that the ref, start and end make sense :)


        let $output := 
            if (not($mediaTypeCompatible)) then
                error($errors:UNSUPPORTED_MEDIA_TYPE, "The requested media type is not compatible with the document format. Media type: " || $mediaType || ", Namespace: " || $namespace)
            else if (not($ref) and not($start) and not($end)) then
                $document
            else if ($namespace eq "mei") then
                dts-document:MEISelect($document, $ref, $start, $end, $tree)                    
            else
                error($errors:UNSUPPORTED_DOCUMENT_FORMAT, "The format of the requested document is not supported. Namespace: " || $namespace )
        
        let $base := concat(replace(system:get-module-load-path(), 'embedded-eXist-server', ''), '/../xslt/')
        let $output := transform:transform($output, concat($base, 'edirom_prepareAnnotsForRendering.xsl'), <parameters/>)
            
        return
            document { $output }
};
