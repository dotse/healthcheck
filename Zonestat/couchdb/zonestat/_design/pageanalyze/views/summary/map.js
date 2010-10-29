function(doc){
    if(doc.pageanalyze.http) {
        emit([doc.testrun, 'http'], doc.pageanalyze.http.summary);
    }
    if(doc.pageanalyze.https) {
        emit([doc.testrun, 'https'], doc.pageanalyze.https.summary);
    }
}