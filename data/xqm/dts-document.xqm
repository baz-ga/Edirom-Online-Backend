xquery version "3.1";

module namespace dts-document = "http://www.edirom.de/api/dts-document";

import module namespace eutil = "http://www.edirom.de/xquery/eutil" at "eutil.xqm";

declare namespace dts = "https://w3id.org/dts/api#";
declare namespace mei = "http://www.music-encoding.org/ns/mei";

declare function dts-document:createMEIOutput(
    $selection as node()*,
    $namespace as xs:string,
    $document as node()
) as node()? {
    if ($namespace eq 'mei') then
        element { node-name($document/*) } {
            namespace xlink { "http://www.w3.org/1999/xlink" },
            $document/*/@*,
            $document//mei:meiHead,
            <music xmlns="http://www.music-encoding.org/ns/mei">
                        <facsimile/>
                        <body>
                            {$selection}
                        </body>
                    </music>
                }
            else
                error(xs:QName("UnsupportedFormat"), "The provided document format is not supported. Namespace: " || $namespace )
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
            if ($tree = "movement" and $ref) then
                let $selection := ($document/id($ref))
                return
                    dts-document:createMEIOutput($selection, $namespace, $document)

            else if ($tree = "movement" and $start and $end) then
                let $selection := (
                    $document/id($start),
                    $document/id($start)/following-sibling::*[
                        . << $document/id($end)
                    ],
                    $document/id($end)
                )
                return
                    dts-document:createMEIOutput($selection, $namespace, $document)
            else if ($tree eq "movement") then
                $document
            else
                ()
            
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
