function(doc){
    if(doc.inprogress) {
        return;
    } else {
        emit(doc.priority, doc.domain);
    }
}