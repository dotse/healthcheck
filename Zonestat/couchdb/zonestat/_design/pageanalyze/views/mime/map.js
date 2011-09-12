function(doc){
    if(doc.pageanalyze.http.mime) {
        for(var e in doc.pageanalyze.http.mime) {
            emit([doc.testrun, 'http', e], doc.pageanalyze.http.mime[e]);
        }
    }
    if(doc.pageanalyze.https.mime) {
        for(var e in doc.pageanalyze.https.mime) {
            emit([doc.testrun, 'https', e], doc.pageanalyze.https.mime[e]);
        }
    }
}