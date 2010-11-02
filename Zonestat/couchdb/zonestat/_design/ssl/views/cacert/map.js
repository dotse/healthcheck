function(doc){
    if (doc.sslscan_web.data.ssltest.certificate['X509v3-Extensions'].extension['X509v3 Basic Constraints'].content == 'CA:TRUE') {
        emit([doc.testrun, doc.domain], 1);
    };
}