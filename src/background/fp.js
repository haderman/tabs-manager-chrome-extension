// origin for this funciton: https://gist.github.com/JamieMason/172460a36a0eaef24233e6edb2706f83
export function baseCompose(f, g) {
  return (...args) => f(g(...args));
}

export function compose(...fns) {
  return fns.reduce(baseCompose);
}

export function pipe(...fns) {
  return fns.reduceRight(baseCompose);
}

export function map(fn) {
  return (arr) => arr.map(fn);
}

export function forEach(fn) {
  return (arr) => arr.forEach(fn);
}

export function zipObject(arrProps = [], arrValues = []) {
  let out = {};
  arrProps.forEach((propName, index) => {
    out[propName] = arrValues[index];
  });
  return out;
}

export function merge(objToMerge) {
  return (baseObject) => ({ ...baseObject, ...objToMerge });
}

export function onlyUnique(value, index, arr) {
  return arr.indexOf(value) === index;
}

export function pick(keys) {
  return (obj) => {
    let out = {};

    if (Array.isArray(keys)) {
      keys.forEach((key) => {
        if (key in obj) {
          out[key] = obj[key];
        }
      });
    }

    if (typeof keys === "string" && keys in obj) {
      out[keys] = obj[keys];
    }

    return out;
  };
}

export function prop(nameProp) {
  return (obj) => obj !== undefined ? obj[nameProp] : undefined;
}

export function set(path = "", value) {
  return (obj = {}) => {
    const clone = { ...obj };
    const props = path.split(".");
    switch (props.length) {
      case 1:
        clone[props[0]] = value;
        break;
      case 2:
        var [first, second] = props;
        if (first in clone) {
          if (second in clone[first]) {
            clone[first][second] = value;
          } else {
            clone[first] = { [second]: value };
          }
        }
        break;
      case 3:
        var [first, second, third] = props;
        if (first in clone) {
          if (second in clone[first]) {
            clone[first][second][third] = value;
          } else {
            clone[first][second] = { [third]: value };
          }
        }
      default:
        break;
    }
    return clone;
  };
}

export function defaultTo(defaultValue) {
  return (value) =>
    value === null || value === undefined ? defaultValue : value;
}
export function length(arr = []) {
  return Array.isArray(arr) ? arr.length : 0;
}
