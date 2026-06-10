xquery version "3.1";
(:
 : For LICENSE-Details please refer to the LICENSE file in the root directory of this repository.
 :)

 (:~
 : This module implements the document endpoint for the Distributed Text Services API.
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
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace system = "http://exist-db.org/xquery/system";
declare namespace transform = "http://exist-db.org/xquery/transform";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace request = "http://exist-db.org/xquery/request";

(: VARIABLE DECLARATIONS ================================================== :)

declare variable $dts-document:alwaysPreserveMEIElements as xs:QName* := (
    QName("http://www.music-encoding.org/ns/mei", "meiHead")
);

declare variable $dts-document:alwaysPreserveTEIElements as xs:QName* := (
    QName("http://www.tei-c.org/ns/1.0", "teiHeader")
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

declare variable $dts-document:referenceAttributes as xs:QName* := (
    QName("", "facs")
);

declare variable $dts-document:specialResources as map(xs:string, xs:string) := map {
    "help_en": "xmldb:exist:///db/apps/Edirom-Online-Backend/help/help_en.xml",
    "help_de": "xmldb:exist:///db/apps/Edirom-Online-Backend/help/help_de.xml"
}; (: TODO: this is a temporary solution.
    There should be a collection also.
    Make them available to collection and navigation endopoints. :)

(: FUNCTION DECLARATIONS =================================================== :)

declare function dts-document:wrapSelection(
    $selection as element()*,
    $document as node()
) as node()? {
    let $alwaysPreserved := $document//*[node-name(.) = $dts-document:alwaysPreserveMEIElements or node-name(.) = $dts-document:alwaysPreserveTEIElements]
    let $baseFullCopyNodes := ($selection, $alwaysPreserved)
    let $referencedNodes := dts-document:referenceClosure($document, $baseFullCopyNodes)
    let $preserveIfPrecedingSiblings := dts-document:preserveIfPrecedingSiblingNodes(($referencedNodes, $referencedNodes/ancestor::*))
    let $fullCopyNodes := dts-document:referenceClosure($document, ($referencedNodes, $preserveIfPrecedingSiblings))
    let $keptNodes := ($fullCopyNodes, $fullCopyNodes/ancestor::*)
    return
        dts-document:copySelection($document/*, $selection, $fullCopyNodes, $keptNodes)
};

declare function dts-document:matchesNode(
    $node as element(),
    $candidates as element()*
) as xs:boolean {
    some $candidate in $candidates
        satisfies $node is $candidate
        or (
            $node/@xml:id
            and $candidate/@xml:id
            and string($node/@xml:id) eq string($candidate/@xml:id)
        )
};

declare function dts-document:preserveIfPrecedingSiblingNodes(
    $keptNodes as element()*
) as element()* {
    $keptNodes/preceding-sibling::*[node-name(.) = $dts-document:preserveIfPrecedingSiblindsMEIElements]
};

declare function dts-document:referenceClosure(
    $document as node(),
    $nodes as element()*
) as element()* {
    let $referencedIds := dts-document:localReferenceIds($nodes)
    let $referencedNodes := $document/id($referencedIds)
    let $newNodes := $referencedNodes except $nodes
    return
        if (empty($newNodes)) then
            $nodes
        else
            dts-document:referenceClosure($document, ($nodes, $referencedNodes))
};

declare function dts-document:localReferenceIds(
    $nodes as element()*
) as xs:string* {
    distinct-values(
        for $attribute in ($nodes/@*, $nodes//@*)[node-name(.) = $dts-document:referenceAttributes]
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

declare function dts-document:copySelection(
    $node as node(),
    $selection as element()*,
    $fullCopyNodes as element()*,
    $keptNodes as element()*
) as node()* {
    typeswitch ($node)
        case element() return
            if (dts-document:matchesNode($node, $fullCopyNodes)) then
                $node
            else if (dts-document:matchesNode($node, $keptNodes)) then
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
    let $selectedChildren := $child/self::element()[dts-document:matchesNode(., $selection)]
    let $isFirstSelectedChild :=
        exists($selectedChildren)
        and empty($child/preceding-sibling::*[dts-document:matchesNode(., $selection)])
    return
        if ($isFirstSelectedChild) then
            <dts:wrapper xmlns:dts="https://w3id.org/dts/api#">{
                for $selectedChild in $node/*[dts-document:matchesNode(., $selection)]
                return dts-document:copySelection($selectedChild, $selection, $fullCopyNodes, $keptNodes)
            }</dts:wrapper>
        else if (exists($selectedChildren)) then
            ()
        else
            dts-document:copySelection($child, $selection, $fullCopyNodes, $keptNodes)
};

declare function dts-document:isInCitationTree(
    $selection as element()*,
    $citationTree as element(citeStructure)*
) as xs:boolean {
    some $citeStructure in ($citationTree, $citationTree//citeStructure)
        satisfies dts-document:matchesCitationStructure($selection, $citeStructure)
};

declare function dts-document:isAlwaysPreservedSelection(
    $selection as element()*
) as xs:boolean {
    every $node in $selection satisfies node-name($node) = $dts-document:alwaysPreserveMEIElements or node-name($node) = $dts-document:alwaysPreserveTEIElements
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

declare function dts-document:selectElementOrRange(
    $document as node(),
    $ref as xs:string?,
    $start as xs:string?,
    $end as xs:string?,
    $citationTree as element(citeStructure)*
) as node()* {
    let $selection :=
        if ($ref) then
            let $idSelection := $document/id($ref)
            return
                if ($idSelection) then
                    $idSelection
                else
                    $document//*[local-name() = $ref]
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
        if (
            $selection
            and (
                dts-document:isInCitationTree($selection, $citationTree)
                or dts-document:isAlwaysPreservedSelection($selection)
            )
            and node-name($selection[1]) eq QName("http://www.tei-c.org/ns/1.0", "pb") 
        ) then
            let $nextPb := ($selection[1]/following::tei:pb)[1]
            let $pb1 := $selection[1]/@xml:id
            let $pb2 := $nextPb/@xml:id
            let $commonAncestorID :=
                if ($nextPb) then
                    ($selection[1]/ancestor-or-self::*[. intersect $nextPb/ancestor-or-self::*])[last()]/@xml:id
                else
                    ($selection[1]/ancestor-or-self::*[. intersect (($document//text())[last()])/ancestor-or-self::*])[last()]/@xml:id
            let $reduced :=
                transform:transform($document, doc('../xslt/reduceToPageById.xsl'),
                    <parameters>
                        <param name="pb1_id" value="{$pb1}"/>
                        <param name="pb2_id" value="{$pb2}"/>
                    </parameters>
                )
            return
                dts-document:wrapSelection($reduced/descendant-or-self::*[@xml:id = $commonAncestorID]/*, $document)
        else if (
            $selection
            and (
                dts-document:isInCitationTree($selection, $citationTree)
                or dts-document:isAlwaysPreservedSelection($selection)
            )
        ) then
            dts-document:wrapSelection($selection, $document)
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
        contains($mediaType, "application/xml") or contains($mediaType, "text/xml") or contains($mediaType, "application/tei+xml") or contains($mediaType, "text/html")
    else if ($namespace eq "edirom") then
        contains($mediaType, "application/xml") or contains($mediaType, "text/xml")
    else
        false()
};

declare function dts-document:resolveResource(
    $resource as xs:string?
) as xs:string {
    if (map:contains($dts-document:specialResources, $resource)) then
        map:get($dts-document:specialResources, $resource)
    else
        $resource
};

declare function dts-document:transformTEIToHTML(
    $xml as node(),
    $resource as xs:string?,
    $xsltBase as xs:string,
    $xslInstruction as processing-instruction()?,
    $htmlParameters as map(xs:string, xs:string)
) as element() {
    let $doc := $xml
    let $xslInstruction :=
        for $i in fn:serialize($xslInstruction, ())
        return
            if (matches($i, 'type="text/xsl"')) then
            (substring-before(substring-after($i, 'href="'), '"'))
        else
            ()

    (: Unpack html parameters :)
    let $lang := if (map:contains($htmlParameters, "lang")) then map:get($htmlParameters, "lang") else ""
    let $idPrefix := if (map:contains($htmlParameters, "idPrefix")) then map:get($htmlParameters, "idPrefix") else ""
    let $autoHead := if (map:contains($htmlParameters, "autoHead")) then map:get($htmlParameters, "autoHead") else "false"
    let $autoToc := if (map:contains($htmlParameters, "autoToc")) then map:get($htmlParameters, "autoToc") else "false"
    let $tocDepth := if (map:contains($htmlParameters, "tocDepth")) then map:get($htmlParameters, "tocDepth") else "1"
    let $footnoteBackLinks := if (map:contains($htmlParameters, "footnoteBackLinks")) then map:get($htmlParameters, "footnoteBackLinks") else "true"
    let $numberHeadings := if (map:contains($htmlParameters, "numberHeadings")) then map:get($htmlParameters, "numberHeadings") else "false"
    let $pageLayout := if (map:contains($htmlParameters, "pageLayout")) then map:get($htmlParameters, "pageLayout") else "CSS"

    let $contextPath := request:get-scheme()|| "://" || request:get-server-name() || ":" || request:get-server-port() || request:get-context-path()

    let $xsl := doc('../xslt/edirom_langReplacement.xsl')
    let $doc := 
        transform:transform($doc, $xsl,
            <parameters>
                <param name="base" value="{$xsltBase}"/>
                <param name="lang" value="{$lang}"/>
            </parameters>
        )

    let $xsl :=
        if ($xslInstruction) then
            ($xslInstruction)
        else
            ('../xslt/tei/profiles/edirom-body/teiBody2HTML.xsl')

    let $params := (
        (: parameters for teiBody2HTML stylesheet :)
        <param name="lang" value="{$lang}"/>,
        <param name="docUri" value="{$resource}"/>,
        <param name="contextPath" value="{$contextPath}"/>,
        <param name="base" value="{$xsltBase}"/>,
        <param name="footnoteBackLink" value="{$footnoteBackLinks}"/>,
        (: parameters for the TEI Stylesheets :)
        <param name="autoHead" value="{$autoHead}"/>,
        <param name="autoToc" value="{$autoToc}"/>,
        <param name="tocDepth" value="{$tocDepth}"/>,
        <param name="documentationLanguage" value="{$lang}"/>,
        <param name="numberHeadings" value="{$numberHeadings}"/>,
        <param name="pageLayout" value="{$pageLayout}"/>
    )

    let $doc := transform:transform($doc, doc($xsl), <parameters>{$params}</parameters>)

    (: TODO: Do something about this: Do a second transformation to add edirom online ID prefixes for unique ID values if object is open mutiple times :)
    let $xsl := '../xslt/edirom_idPrefix.xsl'

    let $params := (
        <param name="idPrefix" value="{$idPrefix}"/>
    )
    let $doc := transform:transform($doc, doc($xsl), <parameters>{$params}</parameters>)

    let $body := $doc//xhtml:body

    return
        element div {
            for $attribute in $body/@*
            return
                $attribute,
            for $node in $body/node()
            return
                $node
        }
};

declare function dts-document:document(
    $resource as xs:string?,
    $ref as xs:string?,
    $start as xs:string?,
    $end as xs:string?,
    $tree as xs:string?,
    $mediaType as xs:string?,
    $htmlParameters as map(xs:string, xs:string)
) as document-node() {
    if ($ref and ($start or $end)) then
        error($errors:INVALID_PARAMETERS, "The 'ref' parameter cannot be used together with 'start' or 'end'.")
    else if (($start and not($end)) or ($end and not($start))) then
        error($errors:INVALID_PARAMETERS, "Both 'start' and 'end' parameters must be provided together.")
    else
        let $resource := dts-document:resolveResource($resource)
        let $document := eutil:getDoc($resource)/root()
        let $document :=
            if ($document) then
                eutil:add-xml-ids($document)
            else
                error($errors:NOT_FOUND, "The requested resource was not found.")
        let $namespace := eutil:getNamespace($document/*)
        let $citationTree := eutil:getDoc($eutil:app-root || '/data/trees/citationTrees' || upper-case($namespace) || '.xml')/refsDecl/citeStructure[
            not($tree) or @xml:id = $tree
        ]
        let $mediaTypeCompatible := dts-document:isMediaTypeCompatible($mediaType, $namespace)


        let $outputXmlRaw := 
            if (not($mediaTypeCompatible)) then
                error($errors:UNSUPPORTED_MEDIA_TYPE, "The requested media type is not compatible with the document format. Media type: " || $mediaType || ", Namespace: " || $namespace)
            else if (not($ref) and not($start) and not($end)) then
                $document/*
            else if ($namespace eq "mei" or $namespace eq "tei") then
                dts-document:selectElementOrRange($document, $ref, $start, $end, $citationTree)                    
            else
                error($errors:UNSUPPORTED_DOCUMENT_FORMAT, "The format of the requested document is not supported. Namespace: " || $namespace )
        
        (: TODO: transformations should be applied here only when edirom output is requested :)
        let $xsltBase := concat(replace(system:get-module-load-path(), 'embedded-eXist-server', ''), '/../xslt/')
        let $outputXml := transform:transform($outputXmlRaw, concat($xsltBase, 'edirom_prepareAnnotsForRendering.xsl'), <parameters/>)

        let $output :=
            if (contains($mediaType, "xml")) then
                document { $outputXml }
            else if ($namespace eq "tei" and contains($mediaType, "html")) then
                let $xslInstruction := $document//processing-instruction(xml-stylesheet)
                return
                    document { dts-document:transformTEIToHTML($outputXml, $resource, $xsltBase, $xslInstruction, $htmlParameters) }
            (:
            else if ($namespace eq "mei" and contains($mediaType, "html") and $ref eq "meiHead") then
                TODO
            :)
            else
                error($errors:UNSUPPORTED_MEDIA_TYPE, "The requested media type is not supported. Media type: " || $mediaType || ", Namespace: " || $namespace || ", Ref: " || $ref)
        return
            $output
};
