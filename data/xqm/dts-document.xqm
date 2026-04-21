xquery version "3.1";

module namespace dts-document = "http://www.edirom.de/api/dts-document";

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
    else (: TODO: test start without end and vice versa:)
        let $mei := doc($resource)/root()

        let $mdiv := 
            if ($tree = "movement" and $ref) then
                ($mei/id($ref))
            else if ($tree = "movement" and $start and $end) then
                (
                    $mei/id($start),
                    $mei/id($start)/following-sibling::*[
                        . << $mei/id($end)
                    ],
                    $mei/id($end)
                )
            else
                ()

        return
            document { (: $mei :)
                <document>
                    <message>This is a document endpoint.</message>
                    <parameters>
                        <resource>{if (exists($resource)) then $resource else "Not provided"}</resource>
                        <ref>{if (exists($ref)) then $ref else "Not provided"}</ref>
                        <start>{if (exists($start)) then $start else "Not provided"}</start>
                        <end>{if (exists($end)) then $end else "Not provided"}</end>
                        <tree>{if (exists($tree)) then $tree else "Not provided"}</tree>
                        <mediaType>{if (exists($mediaType)) then $mediaType else "Not provided"}</mediaType>
                        <result>{if (exists($mdiv)) then $mdiv else "No tree fragment requested"}</result>
                    </parameters>
                </document>
            }
};
