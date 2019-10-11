'use strinct';

// source: https://github.com/pomber/didact

let rootInstance = null;

function render(element, container) {
  const prevInstance = rootInstance;
  const nextInstance = reconcile(container, prevInstance, element);
  rootInstance = nextInstance;
}

function reconcile(parentDom, instance, element) {
  if (instance === null || instance === undefined) {
    // Create instance
    const newInstance = instantiate(element);
    parentDom.appendChild(newInstance.dom);
    return newInstance;
  } else if (element === null || element === undefined) {
    // Remove instance
    parentDom.removeChild(instance.dom);
  } else if (instance.element.type === element.type) {
    // Update instance
    updateDomProperties(instance.dom, instance.element.props, element.props);
    instance.childInstances = reconcileChildren(instance, element);
    instance.element = element;
    return instance;
  } else {
    // Replace instance
    const newInstance = instantiate(element);
    parentDom.replaceChild(newInstance.dom, instance.dom);
    return newInstance;
  }
}

function reconcileChildren(instance, element) {
  const dom = instance.dom;
  const childInstances = instance.childInstances;
  const nextChildElements = element.props.children || [];
  const newChildInstances = [];
  const count = Math.max(childInstances.length, nextChildElements.length);
  for (let i = 0; i < count; i++) {
    const childInstance = childInstances[i];
    const childElement = nextChildElements[i];
    const newChildInstance = reconcile(dom, childInstance, childElement);
    newChildInstances.push(newChildInstance);
  }
  return newChildInstances.filter(instance => instance !== null);
}

function instantiate(element) {
  const { type, props } = element;

  // Create DOM element
  const isTextElement = type === 'text';
  const dom = isTextElement
    ? document.createTextNode('')
    : document.createElement(type);

  updateDomProperties(dom, [], props);
    
  // Instantiate and append children
  const childElements = props.children || [];
  const childInstances = childElements.map(instantiate);
  const childDoms = childInstances.map(childInstance => childInstance.dom);
  childDoms.forEach(childDom => dom.appendChild(childDom));

  const instance = { dom, element, childInstances };
  return instance;
}

function updateDomProperties(dom, prevProps, nextProps) {
  const isEvent = name => name.startsWith("on");
  const isAttribute = name => !isEvent(name) && name != "children";

  // Remove event listeners
  Object.keys(prevProps).filter(isEvent).forEach(name => {
    const eventType = name.toLowerCase().substring(2);
    dom.removeEventListener(eventType, prevProps[name]);
  });

  // Remove attributes
  Object.keys(prevProps).filter(isAttribute).forEach(name => {
    dom[name] = null;
  });

  // Set attributes
  Object.keys(nextProps).filter(isAttribute).forEach(name => {
    dom[name] = nextProps[name];
  });

  // Add event listeners
  Object.keys(nextProps).filter(isEvent).forEach(name => {
    const eventType = name.toLowerCase().substring(2);
    dom.addEventListener(eventType, nextProps[name]);
  });
}

function createElement(type, config, ...args) {
  const props = Object.assign({}, config);
  const hasChildren = args.length > 0;
  const rawChildren = hasChildren ? [].concat(...args) : [];
  props.children = rawChildren
    .filter(c => c != null && c !== false)
    .map(c => c instanceof Object ? c : text(c));
  return { type, props };
}

function text(nodeValue) {
  return {
    type: 'text',
    props: { nodeValue }
  };
}

function createElementFactory(type) {
  return (config, ...args) => createElement(type, config, ...args);
}

function classnames(...args) {
  return args.join(' ');
}

const nav = createElementFactory('nav');
const section = createElementFactory('section');
const div = createElementFactory('div');
const ul = createElementFactory('ul');
const li = createElementFactory('li');
const span = createElementFactory('span');
const button = createElementFactory('button');
const img = createElementFactory('img');
const h1 = createElementFactory('h1');
const h2 = createElementFactory('h2');
const h3 = createElementFactory('h3');
const h4 = createElementFactory('h4');
const h5 = createElementFactory('h5');
const p = createElementFactory('p');
const input = createElementFactory('input');