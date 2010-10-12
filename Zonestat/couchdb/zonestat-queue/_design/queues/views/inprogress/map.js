function(doc){
    if (doc.inprogress) {
        emit(doc.tester_pid, doc.domain);
    };
}