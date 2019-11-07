'use strinct';

const svgNS = 'http://www.w3.org/2000/svg';
const SVG_ELEMENTS = {
  svg: true,
  circle: true,
  path: true,
  rect: true,
  line: true,
  g: true,
};

// source: https://github.com/pomber/didact
// https://blog.atulr.com/react-custom-renderer-1/

let rootInstance = null;

function render(element, container) {
  const prevInstance = rootInstance;
  const nextInstance = reconcile(container, prevInstance, element);
  rootInstance = nextInstance;
}

function reconcile(parentDom, instance, element) {
  if (instance == null) {
    // Create instance
    const newInstance = instantiate(element);
    parentDom.appendChild(newInstance.dom);
    
    return newInstance;
  } else if (element == null) {
    // Remove instance
    parentDom.removeChild(instance.dom);
    return null;
  } else if (instance.element.type !== element.type) {
    // Replace instance
    const newInstance = instantiate(element);
    parentDom.replaceChild(newInstance.dom, instance.dom);
    return newInstance;
  } else if (typeof element.type === 'string') {
    // Update dom instance
    updateDomProperties(instance.dom, instance.element.props, element.props);
    instance.childInstances = reconcileChildren(instance, element);
    instance.element = element;
    return instance;
  } else {
    //Update composite instance
    instance.publicInstance.props = element.props;
    const childElement = instance.publicInstance.render();
    const oldChildInstance = instance.childInstance;
    const childInstance = reconcile(parentDom, oldChildInstance, childElement);
    instance.dom = childInstance.dom;
    instance.childInstance = childInstance;
    instance.element = element;
    return instance;
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
  const isDomElement = typeof type === 'string';

  if (isDomElement) {
    // Create DOM element
    const isTextElement = type === 'text';
    const isSvgElement = SVG_ELEMENTS[type];

    const dom = isTextElement
      ? document.createTextNode('')
      : isSvgElement ? document.createElementNS(svgNS, type)
      : document.createElement(type);

    updateDomProperties(dom, [], props);
      
    // Instantiate and append children
    const childElements = props.children || [];
    const childInstances = childElements.map(instantiate);
    const childDoms = childInstances.map(childInstance => childInstance.dom);
    childDoms.forEach(childDom => dom.appendChild(childDom));
  
    if (element.props.ref) {
      setTimeout(function callRef() {
        element.props.ref(dom);  
      });
    }

    const instance = { dom, element, childInstances };
    return instance;
  } else {
    // Instantiate component element
    const instance = {};
    const publicInstance = createPublicInstance(element, instance);
    const childElement = publicInstance.render();
    const childInstance = instantiate(childElement);
    const dom = childInstance.dom;

    Object.assign(instance, { dom, element, childInstance, publicInstance });
    return instance;
  }
}

function createPublicInstance(element, internalInstance) {
  const { type, props } = element;
  const publicInstance = new type(props);
  publicInstance.__internalInstance = internalInstance;
  return publicInstance;
}

function updateDomProperties(dom, prevProps, nextProps) {
  const isEvent = name => name.startsWith('on');
  const isAttribute = name => !isEvent(name) && name !== 'children';

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
    const isSvgElement = SVG_ELEMENTS[dom.tagName];
    if (isSvgElement) {
      const nameNS = name.replace('_', '-');
      dom.setAttributeNS(null, nameNS, nextProps[name]);
    } else {
      dom[name] = nextProps[name];
    }
  });

  // Add event listeners
  Object.keys(nextProps).filter(isEvent).forEach(name => {
    const eventType = name.toLowerCase().substring(2);
    dom.addEventListener(eventType, nextProps[name]);
  });
}

function createElement(type, config, ...children) {
  const props = Object.assign({}, config);
  const hasChildren = children.length > 0;
  const rawChildren = hasChildren ? [].concat(...children) : [];
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
  return (config, ...children) => createElement(type, config, ...children);
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
const canvas = createElementFactory('canvas');
const object = createElementFactory('object');

const svg = createElementFactory('svg');
svg.circle = createElementFactory('circle');
svg.path = createElementFactory('path');
svg.rect = createElementFactory('rect');
svg.line = createElementFactory('line');
svg.filter = createElementFactory('filter');
svg.g = createElementFactory('g');
svg.feGaussianBlur = createElementFactory('feGaussianBlur');