<script>
export let val = 0;

function renderHuman(date) {
  const hms = [date.getHours(), date.getMinutes(), date.getSeconds()].map(v => {
    return String(v < 10 ? '0' + v : v);
  });

  hms.pop(); // TODO: Make it smarter
  return hms.join(':');
}

$: date = new Date(val.replace(/T/, ' '));
$: human = renderHuman(date);
</script>

<b class="ts">{human}</b>