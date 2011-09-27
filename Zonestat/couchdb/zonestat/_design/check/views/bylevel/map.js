function(doc){
    var count = {
            "CRITICAL": 0,
            "ERROR": 0,
            "WARNING": 0,
            "NOTICE": 0,
            "INFO": 0
        };

    for (var dc in doc.dnscheck) {
        count[doc.dnscheck[dc].level] += 1;
    }

    emit([doc.testrun, doc.domain], count);
    if(count["CRITICAL"] > 0) {
        emit(["CRITICAL", doc.testrun, doc.domain], undefined);
    }
    if(count["ERROR"] > 0) {
        emit(["ERROR", doc.testrun, doc.domain], undefined);
    }
    if(count["WARNING"] > 0) {
        emit(["WARNING", doc.testrun, doc.domain], undefined);
    }
    if(count["NOTICE"] > 0) {
        emit(["NOTICE", doc.testrun, doc.domain], undefined);
    }
    if(count["INFO"] > 0) {
        emit(["INFO", doc.testrun, doc.domain], undefined);
    }
}