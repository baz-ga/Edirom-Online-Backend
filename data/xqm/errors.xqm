xquery version "3.1";
(:
 : For LICENSE-Details please refer to the LICENSE file in the root directory of this repository.
 :)

 (:~
 : This module provides library functions for handling errors
 :
 : @author Francesco Maccarini
 :)
module namespace errors = "http://www.edirom.de/xquery/errors";

(: IMPORTS ================================================================= :)

(: NAMESPACE DECLARATIONS ================================================== :)

(: VARIABLE DECLARATIONS =================================================== :)

(:
    Error codes for the DTS API
 :)
declare variable $errors:INVALID_PARAMETERS := QName("http://www.edirom.de/api/dts-document", "InvalidParametersError");
declare variable $errors:UNSUPPORTED_MEDIA_TYPE := QName("http://www.edirom.de/api/dts-document", "UnsupportedMediaTypeError");
declare variable $errors:UNSUPPORTED_DOCUMENT_FORMAT := QName("http://www.edirom.de/api/dts-document", "UnsupportedDocumentFormatError");
declare variable $errors:NOT_FOUND := QName("http://www.edirom.de/api/dts-document", "NotFoundError");

(: FUNCTION DECLARATIONS =================================================== :)

