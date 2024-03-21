const toggle = (isAprilFools) => {
  const body = document.querySelector("body");
  if (isAprilFools) {
    body.classList.add("april-fools");
  } else {
    body.classList.remove("april-fools");
  }
}

const callback = () => {
  const jstNow = new Date(Date.now() + ((new Date().getTimezoneOffset() + (9 * 60)) * 60 * 1000));
  const month = 3; // 3 is April
  const day = 1;
  if (jstNow.getMonth() === month && jstNow.getDate() === day) {
    toggle(true);
  } else {
    toggle(false);
  }
}

const gap = Math.max(60 - new Date().getSeconds() - 1, 0);
callback();
setTimeout(() => {
  callback();
  setInterval(callback, 10000);
}, gap * 1000)
