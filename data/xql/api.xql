xquery version "3.1";

declare namespace api="http://www.edirom.de/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace svg="http://www.w3.org/2000/svg";
declare namespace exist="http://exist.sourceforge.net/NS/exist";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace roaster="http://e-editiones.org/roaster";

import module namespace auth="http://e-editiones.org/roaster/auth";
import module namespace rutil="http://e-editiones.org/roaster/util";
import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace cookie="http://e-editiones.org/roaster/cookie";
import module namespace dts-document="http://www.edirom.de/api/dts-document" at "../xqm/dts-document.xqm";


(:~
 : list of definition files to use
 :)
declare variable $api:definitions := ("data/api/api.json");


(:~
 : DTS-oriented route handlers
 :)
declare function api:entryPoint ($request as map(*)) {
    let $base-url := substring-before(request:get-url(), "/api")
    return
    map {
        "@context": "https://dtsapi.org/context/v1.0.json",
        "dtsVersion": "1.0",
        "@id": concat($base-url, "/api/"),
        "@type": "EntryPoint",
        "collection": concat($base-url, "/api/collection/{?id,page,nav}"),
        "navigation" : concat($base-url, "/api/navigation/{?resource,ref,start,end,down,tree,page}"),
        "document": concat($base-url, "/api/document/{?resource,ref,start,end,tree,mediaType}")
    }
};

declare function api:collection ($request as map(*)) {
    map {
        "message": "This is a collection endpoint."
     }
};

declare function api:navigation ($request as map(*)) {
    map {
        "message": "This is a navigation endpoint."
     }
};

declare function api:document ($request as map(*)) {
    let $base-url := substring-before(request:get-url(), "/api")
    let $resource := xs:string($request?parameters?resource)
    let $mediaType := xs:string($request?parameters?mediaType)
    let $headers := map {
        "Link": concat($base-url, '/api/collection/?resource=', $resource, '; rel="collection"')
    }
    return
        try {
            let $document := dts-document:document(
                $resource,
                if (exists($request?parameters?ref)) then xs:string($request?parameters?ref) else "",
                if (exists($request?parameters?start)) then xs:string($request?parameters?start) else "",
                if (exists($request?parameters?end)) then xs:string($request?parameters?end) else "",
                xs:string($request?parameters?tree),
                $mediaType
            )
            return
                roaster:response(200, $mediaType, $document, $headers)
        } catch dts-document:UnsupportedMediaTypeError {
            roaster:response(404, "application/json", map {
                "error": "UnsupportedMediaType",
                "message": $err:description
            })
        } catch dts-document:InvalidParametersError {
            roaster:response(404, "application/json", map {
                "error": "InvalidParameters",
                "message": $err:description
            })
        } catch dts-document:UnsupportedDocumentFormatError {
            roaster:response(404, "application/json", map {
                "error": "UnsupportedDocumentFormat",
                "message": $err:description
            })
        } catch dts-document:NotFoundError {
            roaster:response(404, "application/json", map {
                "error": "NotFound",
                "message": $err:description
            })
        } catch * {
            roaster:response(500, "application/json", map {
                "error": $err:code,
                "message": $err:description
            })
        }
    

    
};
(: end of route handlers :)

(:~
 : This function "knows" all modules and their functions
 : that are imported here 
 : You can leave it as it is, but it has to be here
 :)
declare function api:lookup ($name as xs:string) {
    function-lookup(xs:QName($name), 1)
};

(: util:declare-option("output:indent", "no"), :)
roaster:route($api:definitions, api:lookup#1)
