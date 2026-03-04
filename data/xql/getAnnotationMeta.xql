xquery version "3.1";

(:
 : Copyright: For LICENSE-Details please refer to the LICENSE file in the root directory of this repository.
 :)

(:~
    Returns the HTML for a specific annotation for an AnnotationView.

    @author <a href="mailto:kepper@edirom.de">Johannes Kepper</a>
:)

(: IMPORTS ================================================================= :)

import module namespace annotation = "http://www.edirom.de/xquery/annotation" at "../xqm/annotation.xqm";
import module namespace doc = "http://www.edirom.de/xquery/document" at "../xqm/document.xqm";
import module namespace eutil = "http://www.edirom.de/xquery/eutil" at "../xqm/eutil.xqm";
import module namespace source = "http://www.edirom.de/xquery/source" at "../xqm/source.xqm";
import module namespace taxonomy = "http://www.edirom.de/xquery/taxonomy" at "../xqm/taxonomy.xqm";

(: NAMESPACE DECLARATIONS ================================================== :)

declare namespace mei = "http://www.music-encoding.org/ns/mei";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace request = "http://exist-db.org/xquery/request";

(: OPTION DECLARATIONS ===================================================== :)

declare option output:method "xhtml";
declare option output:media-type "text/html";

let $lang := request:get-parameter('lang', '')
let $edition := request:get-parameter('edition', '')
let $uri := request:get-parameter('uri', '')
let $docUri := substring-before($uri, '#')
let $internalId := substring-after($uri, '#')
let $doc := eutil:getDoc($docUri)
let $annot := $doc/id($internalId)

let $participants := annotation:getParticipants($annot)

let $classElements :=
    for $classIDREF in annotation:get-class-idrefs-as-sequence($annot)
    return $doc/id($classIDREF)

let $taxonomyGroups :=
    for $elem in $classElements[ancestor::mei:taxonomy]
    let $taxonomyId := taxonomy:get-parent-taxonomy-identifying-string($elem)
    group by $taxonomyId
    let $taxonomyElem := $elem[1]/ancestor-or-self::mei:taxonomy[1]
    let $taxonomyLabels := taxonomy:get-labels($taxonomyElem)
    let $taxonomyLabel := ($taxonomyLabels($lang)[. != ''], $taxonomyLabels('und')[. != ''], $taxonomyId)[1]
    let $displayLabel := if ($taxonomyLabel != $taxonomyId) then $taxonomyLabel else eutil:getLanguageString($taxonomyId, ())
    return
        map {
            'id': $taxonomyId,
            'label': $displayLabel,
            'values': string-join(
                for $e in $elem
                return taxonomy:get-label-localized-as-string($e),
                ', '
            )
        }

let $sigla := source:getSiglaAsArray($participants)
let $siglaLabel := switch (count($sigla))
    case 0 return
        ()
    case 1 return
        eutil:getLanguageString('view.window.AnnotationView_Source', ())
    default return
        eutil:getLanguageString('view.window.AnnotationView_Sources', ())

let $annotIDlabel := eutil:getLanguageString('view.window.AnnotationView_AnnotationID', ())

return

    <div class="annotView">
        <div class="metaBox">
            {
                for $t in $taxonomyGroups
                (: TODO process single vs. _multiple for keys :)
                return
                    <div class="property taxonomy-{$t('id')}">
                        <div class="key">{$t('label')}</div>
                        <div class="value">{$t('values')}</div>
                    </div>
            }
            <div class="property sourceSiglums">
                <div class="key">{$siglaLabel}</div>
                <div class="value">{string-join($sigla, ', ')}</div>
            </div>
            <div class="property annotID">
                <div class="key">{$annotIDlabel}</div>
                <div class="value">{$internalId}</div>
            </div>
        </div>
    </div>
