function(doc){
    if (doc.sslscan_web.data.ssltest.certificate.subject) {
        emit([doc.testrun, doc.domain], doc.sslscan_web.data.ssltest.certificate.subject.match( /\/CN=([^/]+)/ )[1]);
    };
}