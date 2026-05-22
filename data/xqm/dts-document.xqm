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

(: VARIABLE DECLARATIONS ================================================== :)

declare variable $dts-document:alwaysPreserveMEIElements as xs:QName* := (
    QName("http://www.music-encoding.org/ns/mei", "meiHead")
);

declare variable $dts-document:preserveIfPrecedingSiblindsMEIElements as xs:QName* := (
    QName("http://www.music-encoding.org/ns/mei", "scoreDef"),
    QName("http://www.music-encoding.org/ns/mei", "staffGrp"),
    QName("http://www.music-encoding.org/ns/mei", "staffDef"),
    QName("http://www.music-encoding.org/ns/mei", "layerDef"),
    QName("http://www.music-encoding.org/ns/mei", "clef"),
    QName("http://www.music-encoding.org/ns/mei", "clefGrp"),
    QName("http://www.music-encoding.org/ns/mei", "keySig"),
    QName("http://www.music-encoding.org/ns/mei", "keyAccid"),
    QName("http://www.music-encoding.org/ns/mei", "label"),
    QName("http://www.music-encoding.org/ns/mei", "meterSig"),
    QName("http://www.music-encoding.org/ns/mei", "meterSigGrp"),
    QName("http://www.music-encoding.org/ns/mei", "graphic")
);

(: FUNCTION DECLARATIONS =================================================== :)

declare function dts-document:wrapMEISelection(
    $selection as element()*,
    $document as node()
) as node()? {
    let $alwaysPreserved := $document//*[node-name(.) = $dts-document:alwaysPreserveMEIElements]
    let $baseFullCopyNodes := ($selection, $alwaysPreserved)
    let $baseKeptNodes := ($baseFullCopyNodes, $baseFullCopyNodes/ancestor::*)
    let $preserveIfPrecedingSiblings := dts-document:preserveIfPrecedingSiblingNodes($baseKeptNodes)
    let $fullCopyNodes := ($baseFullCopyNodes, $preserveIfPrecedingSiblings)
    (: let $fullCopyNodes := dts-document:referenceClosure($document, ($selection, $alwaysPreserved)) :)
    let $keptNodes := ($fullCopyNodes, $fullCopyNodes/ancestor::*)
    return
        dts-document:copyMEISelection($document/*, $selection, $fullCopyNodes, $keptNodes)
};

declare function dts-document:preserveIfPrecedingSiblingNodes(
    $keptNodes as element()*
) as element()* {
    $keptNodes/preceding-sibling::*[node-name(.) = $dts-document:preserveIfPrecedingSiblindsMEIElements]
};

(: TODO: redefine the closure :)

(:
declare function dts-document:referenceClosure(
    $document as node(),
    $nodes as element()*
) as element()* {
    let $referencedIds := dts-document:localReferenceIds($nodes)
    let $referencedNodes := $document/id($referencedIds)
    let $reverseReferringNodes := dts-document:elementsReferencingIds($document, ($nodes/@xml:id, $nodes//@xml:id))
    let $newNodes := ($referencedNodes, $reverseReferringNodes) except $nodes
    return
        if (empty($newNodes)) then
            $nodes
        else
            dts-document:referenceClosure($document, ($nodes, $referencedNodes, $reverseReferringNodes))
};

declare function dts-document:localReferenceIds(
    $nodes as element()*
) as xs:string* {
    distinct-values(
        for $attribute in ($nodes/@*, $nodes//@*)
        return dts-document:localReferenceIdsFromAttributes($attribute)
    )
};

declare function dts-document:localReferenceIdsFromAttributes(
    $attributes as attribute()*
) as xs:string* {
    distinct-values(
        for $attribute in $attributes
        for $token in tokenize(normalize-space(string($attribute)), "\s+")
        where starts-with($token, "#") and matches(substring($token, 2), "^[A-Za-z_][A-Za-z0-9_.-]*$")
        return substring($token, 2)
    )
};

declare function dts-document:elementsReferencingIds(
    $document as node(),
    $ids as xs:string*
) as element()* {
    if (empty($ids)) then
        ()
    else
        $document//*[some $id in dts-document:localReferenceIdsFromAttributes(@*) satisfies $id = $ids]
};
:)

declare function dts-document:copyMEISelection(
    $node as node(),
    $selection as element()*,
    $fullCopyNodes as element()*,
    $keptNodes as element()*
) as node()* {
    typeswitch ($node)
        case element() return
            if ($node intersect $fullCopyNodes) then
                $node
            else if ($node intersect $keptNodes) then
                element { node-name($node) } {
                    namespace { "xlink" } { "http://www.w3.org/1999/xlink" },
                    $node/@*,
                    dts-document:copySelectedChildren($node, $selection, $fullCopyNodes, $keptNodes)
                }
            else
                ()
        default return
            $node
};

declare function dts-document:copySelectedChildren(
    $node as element(),
    $selection as element()*,
    $fullCopyNodes as element()*,
    $keptNodes as element()*
) as node()* {
    for $child in $node/node()
    let $selectedChildren := $child/self::element()[. intersect $selection]
    let $isFirstSelectedChild :=
        exists($selectedChildren)
        and empty($child/preceding-sibling::*[. intersect $selection])
    return
        if ($isFirstSelectedChild) then
            <dts:wrapper xmlns:dts="https://w3id.org/dts/api#">{
                for $selectedChild in $node/*[. intersect $selection]
                return dts-document:copyMEISelection($selectedChild, $selection, $fullCopyNodes, $keptNodes)
            }</dts:wrapper>
        else if (exists($selectedChildren)) then
            ()
        else
            dts-document:copyMEISelection($child, $selection, $fullCopyNodes, $keptNodes)
};

declare function dts-document:isInCitationTree(
    $selection as element()*,
    $citationTree as element(citeStructure)*
) as xs:boolean {
    some $citeStructure in ($citationTree, $citationTree//citeStructure)
        satisfies dts-document:matchesCitationStructure($selection, $citeStructure)
};

declare function dts-document:matchesCitationStructure(
    $selection as element()*,
    $citeStructure as element(citeStructure)
) as xs:boolean {
    let $match := normalize-space($citeStructure/@match)
    let $matchName :=
        if (not($match)) then
            ()
        else
            resolve-QName($match, $citeStructure)
    return
        exists($matchName)
        and (every $node in $selection satisfies node-name($node) eq $matchName)
};

declare function dts-document:MEISelect(
    $document as node(),
    $ref as xs:string?,
    $start as xs:string?,
    $end as xs:string?,
    $citationTree as element(citeStructure)*
) as node()* {
    let $selection :=
        if ($ref) then
            $document/id($ref)
        else if ($start and $end) then
            let $startNode := $document/id($start)
            let $endNode := $document/id($end)
                return
                    if ($start eq $end and $startNode) then
                        $startNode
                    else if ($startNode and $endNode and not($startNode/parent::* is $endNode/parent::*)) then
                        error($errors:INVALID_PARAMETERS, "The start and end citable units must have the same parent.")
                    else if ($startNode and $endNode and ($startNode << $endNode)) then
                        (
                            $startNode,
                            $startNode/following-sibling::*[
                                . << $endNode
                            ],
                            $endNode
                        )
                    else
                        error($errors:INVALID_PARAMETERS, "Invalid start and end citable units. Start: " || $start || ", End: " || $end)
        else
            ()
    return
        if ($selection and dts-document:isInCitationTree($selection, $citationTree)) then
            dts-document:wrapMEISelection($selection, $document)
        else if ($selection) then
            error($errors:INVALID_PARAMETERS, "The selected citable units are not part of the citation tree specified for this document." || "Citation tree: " || string-join($citationTree/@xml:id, ", ") || ". Selected element: " || node-name($selection[1]) || ", Selected element @xml:id: " || $selection[1]/@xml:id)
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
        let $citationTree := doc($eutil:app-root || '/data/trees/citationTreesMEI.xml')/refsDecl/citeStructure[
            not($tree) or @xml:id = $tree
        ]
        let $namespace := 
            if ($document) then
                eutil:getNamespace($document/*)
            else
                error($errors:NOT_FOUND, "The requested resource was not found.")

        let $mediaTypeCompatible := dts-document:isMediaTypeCompatible($mediaType, $namespace)


        let $output := 
            if (not($mediaTypeCompatible)) then
                error($errors:UNSUPPORTED_MEDIA_TYPE, "The requested media type is not compatible with the document format. Media type: " || $mediaType || ", Namespace: " || $namespace)
            else if (not($ref) and not($start) and not($end)) then
                $document/*
            else if ($namespace eq "mei") then
                dts-document:MEISelect($document, $ref, $start, $end, $citationTree)                    
            else
                error($errors:UNSUPPORTED_DOCUMENT_FORMAT, "The format of the requested document is not supported. Namespace: " || $namespace )
        
        let $xsltBase := concat(replace(system:get-module-load-path(), 'embedded-eXist-server', ''), '/../xslt/')
        let $output := transform:transform($output, concat($xsltBase, 'edirom_prepareAnnotsForRendering.xsl'), <parameters/>)
            
        return
            document { $output }
};
