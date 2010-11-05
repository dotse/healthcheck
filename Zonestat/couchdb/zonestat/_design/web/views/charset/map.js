function(doc){
    if(doc.webinfo.http) {
        emit([doc.testrun, 'http', doc.webinfo.http.charset], 1);
    }
    if(doc.webinfo.https) {
        emit([doc.testrun, 'https', doc.webinfo.https.charset], 1);
    }
}