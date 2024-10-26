const init = async _ => {
    const zjb = new Zjb();

    const params = {
        env: {
            memory: new WebAssembly.Memory({ initial: 1 }),
            __stack_pointer: 0,
        },
        zjb: zjb.imports,
    };

    const request = fetch('core.wasm');
    const module = await WebAssembly.instantiateStreaming(request, params);
    zjb.setInstance(module.instance);
    const exports = module.instance.exports;

    const canvas = document.querySelector('body > canvas');
    canvas.onclick = e => {
        const rect = canvas.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;
        
        exports.click(x, y);
    };

    document.querySelector('body > button').onclick = _ => {
        exports.clear(canvas.width, canvas.height);
    };

    const resizeCanvas = _ => {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;

        exports.clear(canvas.width, canvas.height);
    };

    resizeCanvas();

    let sinceLastResize;
    window.onresize = _ => {
        clearTimeout(sinceLastResize);
    
        sinceLastResize = setTimeout(resizeCanvas, 250);
    };
};

init();

