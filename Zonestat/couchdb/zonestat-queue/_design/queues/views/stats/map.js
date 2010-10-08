function(doc){
    if(doc.inprogress) {
        emit('inprogress',1);
    } else {
        emit(doc.priority,1);
    }
}