const root = document.getElementById('root');
const div = document.createElement('div');
root.append(div);

const msg = { type: 'get_titles' };
chrome.extension.sendMessage(msg, titles => {
  // div.textContent = titles && titles.join && titles.join(', ');
});

const $btnCreateWorkspace = document.getElementById('btn-create-workspace');
$btnCreateWorkspace.addEventListener('click', tryCreateWorkspace);

function tryCreateWorkspace() {
  const $inputWorkspace = document.getElementById('input-workspace');
  const msg = { type: 'create_workspace', payload: $inputWorkspace.value };
  chrome.extension.sendMessage(msg, onWorkspaceCreated);
}

function onWorkspaceCreated(wasSuccess) {
  // alert('workspace created? ' + wasSuccess);
}