function(doc){
    if(doc.webinfo.http) {
        emit([doc.testrun, 'http', doc.webinfo.http.response_code], 1);
    }
    if(doc.webinfo.https) {
        emit([doc.testrun, 'https', doc.webinfo.https.response_code], 1);
    }
}