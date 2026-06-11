xquery version "3.1";

(:
 : Copyright: For LICENSE-Details please refer to the LICENSE file in the root directory of this repository.
 :)

(:~
    Returns the HTML for a specific annotation for an AnnotationView.

    @author <a href="mailto:kepper@edirom.de">Johannes Kepper</a>
    @author <a href="mailto:bohl@edirom.de">Benjamin W. Bohl</a>
:)

(: IMPORTS ================================================================= :)

import module namespace annotation = "http://www.edirom.de/xquery/annotation" at "../xqm/annotation.xqm";
import module namespace doc = "http://www.edirom.de/xquery/document" at "../xqm/document.xqm";
import module namespace edition = "http://www.edirom.de/xquery/edition" at "../xqm/edition.xqm";
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

(: VARIABLE DECLARATIONS =================================================== :)

declare variable $lang := eutil:getSetLanguage(());
declare variable $edition := request:get-parameter('edition', '');
declare variable $uri := request:get-parameter('uri', '');
declare variable $docUri := substring-before($uri, '#');
declare variable $internalId := substring-after($uri, '#');
declare variable $doc := eutil:getDoc($docUri);
declare variable $annot := $doc/id($internalId);
declare variable $annotMap := annotation:toJSON($annot, $edition);
declare variable $priorityLabel := switch (map:get($annotMap, 'priority'))
     case ""
         return
             ()
     default return
         eutil:getLanguageString('ediromPriority', ());
         
declare variable $categoriesLabel :=
    switch (map:get($annotMap, 'categories'))
        case 0 return ()
        case 1 return
             eutil:getLanguageString('ediromCategory', ())
        default return
         eutil:getLanguageString('ediromCategory_multiple', ());
         
(: TODO deprecate below categories and priorities fields with Edirom-Online-API 2.0.0 :)
declare variable  $hideLegacyFields := xs:boolean(edition:getPreference('annotation_hide_legacy_fields', $edition));

(: TODO switch to array return in annotation:toJSON() to avoid loal array :)
declare variable $taxonomiesArray := annotation:get-referenced-categories-as-taxonomy-array($annot, $doc, $lang);

declare variable $annotIDlabel := eutil:getLanguageString('view.window.AnnotationView_AnnotationID', (), $lang);

declare variable $participants := annotation:getParticipants($annot);

declare variable $sources := doc:getDocumentsLabelsAsArray($participants, $edition);

declare variable $sourcesLabel :=
    if (count($sources) gt 1) then
        eutil:getLanguageString('view.window.AnnotationView_Sources', (), $lang)
    else
        eutil:getLanguageString('view.window.AnnotationView_Source', (), $lang);

declare variable $siglaLabel :=
    if (count(map:get($annotMap, 'sigla')) gt 1) then
        eutil:getLanguageString('view.window.AnnotationView_Sigla', (), $lang)
    else
        eutil:getLanguageString('view.window.AnnotationView_Siglum', (), $lang);
        
(: QUERY BODY ============================================================== :)

(:
(\: TODO deprecate below categories and priorities fields with Edirom-Online-API 2.0.0 :\)
let $hideLegacyFields := xs:boolean(edition:getPreference('annotation_hide_legacy_fields', $edition))
let $priority := annotation:getPriorityLabel($annot)
let $priorityLabel := switch ($priority)
     case ""
         return
             ()
     default return
         eutil:getLanguageString('ediromPriority', ())

 let $categories := annotation:get-category-labels-as-sequence($annot)
 let $categoriesLabel :=
    switch (count($categories))
        case 0 return ()
        case 1 return
             eutil:getLanguageString('ediromCategory', ())
        default return
         eutil:getLanguageString('ediromCategory_multiple', ())

(\: TODO deprecate above categories and priorities fields with Edirom-Online-API 2.0.0 :\)

let $taxonomiesArray := annotation:get-referenced-categories-as-taxonomy-array($annot, $doc, $lang)

let $sigla := source:getSiglaAsArray($participants)
let $siglaLabel := switch (count($sigla))
    case 0 return
        ()
    case 1 return
        eutil:getLanguageString('view.window.AnnotationView_Source', ())
    default return
        eutil:getLanguageString('view.window.AnnotationView_Sources', ())

let $annotIDlabel := eutil:getLanguageString('view.window.AnnotationView_AnnotationID', ()):)

(: QUERY BODY ============================================================== :)

<div class="annotView">
    <div class="metaBox">
        {
            if($hideLegacyFields) then
                ()
            else (
                (: TODO deprecate priority field with Edirom-Online-API 2.0.0 :)
                <div class="property priority">
                    <div class="key">{$priorityLabel}</div>
                    <div class="value">{map:get($annotMap, 'priority')}</div>
                </div>,
                (: TODO deprecate categories field with Edirom-Online-API 2.0.0 :)
                <div class="property categories">
                    <div class="key">{$categoriesLabel}</div>
                    <div class="value">{string-join(map:get($annotMap, 'categories'), ', ')}</div>
                </div>
            )
        }
        {
            for $t in $taxonomiesArray?*
            return
                <div class="property taxonomy-{$t('id')}">
                    <div class="key">{(eutil:getLanguageString(edition:getLanguageFileURI($edition, $lang), $t('label'), (), $lang), $t('label'))[1]}</div>
                    <div class="value">{string-join($t('items')?*?name, ', ')}</div>
                </div>
        }
        <div class="property sourceLabel">
            <div class="key">{$sourcesLabel}</div>
            <div class="value">{string-join($sources, ', ')}</div>
        </div>
        <div class="property sourceSiglums">
            <div class="key">{$siglaLabel}</div>
            <div class="value">{string-join(map:get($annotMap, 'sigla'), ', ')}</div>
        </div>
        <div class="property annotID">
            <div class="key">{$annotIDlabel}</div>
            <div class="value">{$internalId}</div>
        </div>
    </div>
</div>
