function(doc){
    if (doc.inprogress) {
        emit(doc.priority, doc.domain);
    };
}