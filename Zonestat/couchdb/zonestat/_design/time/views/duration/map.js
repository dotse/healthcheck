function(doc){
    if (doc.start > 0 && doc.finish > 0) {
        var duration = doc.finish - doc.start;
        emit(duration, null);        
    }
}