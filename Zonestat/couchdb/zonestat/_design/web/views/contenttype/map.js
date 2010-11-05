function(doc){
    if(doc.webinfo.http) {
        emit([doc.testrun, 'http', doc.webinfo.http.content_type], 1);
    }
    if(doc.webinfo.https) {
        emit([doc.testrun, 'https', doc.webinfo.https.content_type], 1);
    }
}