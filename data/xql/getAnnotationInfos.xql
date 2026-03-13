xquery version "3.1";
(:
 : Copyright: For LICENSE-Details please refer to the LICENSE file in the root directory of this repository.
 :)


(: IMPORTS ================================================================= :)

import module namespace annotation = "http://www.edirom.de/xquery/annotation" at "../xqm/annotation.xqm";
import module namespace edition = "http://www.edirom.de/xquery/edition" at "../xqm/edition.xqm";
import module namespace taxonomy = "http://www.edirom.de/xquery/taxonomy" at "../xqm/taxonomy.xqm";


(: NAMESPACE DECLARATIONS ================================================== :)

declare namespace mei = "http://www.music-encoding.org/ns/mei";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace request = "http://exist-db.org/xquery/request";


(: OPTION DECLARATIONS ===================================================== :)

declare option output:method "json";
declare option output:media-type "application/json";


(: VARIABLE DECLARATIONS =================================================== :)

declare variable $uri := request:get-parameter('uri', '');
declare variable $edition := request:get-parameter('edition', '');
declare variable $lang := request:get-parameter('lang', '');


(: QUERY BODY ============================================================== :)

let $mei := doc($uri)
let $editionCollection := edition:collection($edition)
let $annots := $editionCollection//mei:annot[matches(@plist, $uri)] | $mei//mei:annot

let $categoryElements := annotation:get-referenced-category-elements($annots, ($mei, $editionCollection))

let $taxonomiesArray := array {
    for $elem in $categoryElements
    let $taxonomyId := taxonomy:get-parent-taxonomy-identifying-string($elem)
    group by $taxonomyId
    let $taxonomyElem := $elem[1]/ancestor-or-self::mei:taxonomy[1]
    let $taxonomyLabels := taxonomy:get-labels($taxonomyElem)
    let $taxonomyLabel := ($taxonomyLabels($lang)[. != ''], $taxonomyLabels('und')[. != ''], $taxonomyId)[1]
    return
        map {
            'id': $taxonomyId,
            'label': $taxonomyLabel,
            'items': array {
                for $id in distinct-values($elem/@xml:id)
                let $e := ($elem[@xml:id = $id])[1]
                order by taxonomy:get-label-localized-as-string($e)
                return
                    map {
                        'id': xs:string($id),
                        'name': taxonomy:get-label-localized-as-string($e)
                    }
            }
        }
}

return
    map {
        'count': count($annots),
        'taxonomies': $taxonomiesArray
    }
