function(doc){
    if(Math.random() <= 0.01) {
        emit(doc.id, null);
    }
}