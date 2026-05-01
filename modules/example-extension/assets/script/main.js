document.querySelectorAll('.ripple-container').forEach(elem => {
      elem.addEventListener('click', e => {
        const ripple = document.createElement('span');
        ripple.classList.add('ripple');
        
        const rect = elem.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height);
        const x = e.clientX - rect.left - size / 2;
        const y = e.clientY - rect.top - size / 2;
        
        ripple.style.width = ripple.style.height = size + 'px';
        ripple.style.left = x + 'px';
        ripple.style.top = y + 'px';
        
        elem.appendChild(ripple);
        setTimeout(() => ripple.remove(), 600);
      });
    });

    const themeBtn = document.getElementById('themeBtn');
    const body = document.body;
    
    themeBtn.addEventListener('click', () => {
      body.classList.toggle('dark-theme');
      themeBtn.textContent = body.classList.contains('dark-theme') 
        ? '切换为浅色主题' 
        : '切换为深色主题';
    });