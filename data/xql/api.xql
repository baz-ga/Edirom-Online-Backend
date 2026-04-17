xquery version "3.1";

declare namespace api="http://www.edirom.de/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace svg="http://www.w3.org/2000/svg";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace roaster="http://e-editiones.org/roaster";

import module namespace auth="http://e-editiones.org/roaster/auth";
import module namespace rutil="http://e-editiones.org/roaster/util";
import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace cookie="http://e-editiones.org/roaster/cookie";


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
    <message>This is a document endpoint.</message>
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