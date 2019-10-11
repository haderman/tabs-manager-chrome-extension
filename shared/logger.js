// EXAMPLE of use:

// logger
//   .group(logger.templates.compose(
//     logger.templates.colorText('Test 1'),
//     logger.templates.separator(' '),
//     logger.templates.chip('text 3', { background: '#a7a7a7', color: '#333' }),
//   ))
//   .log(logger.templates.colorText('hola'))
//   .time(logger.templates.chip)
//   .log(logger.templates.changed('before 3', 'next 3'))
//   .groupEnd();

function createLogger() {
  const toArgs = msg => Array.isArray(msg) ? msg : [msg];

  const chipTemplate = (text, options = {}) => {
    const { background = 'black', color = 'white'} = options;
    const style = [
      `color: ${color}`,
      `background: ${background}`,
      'padding: 3px',
      'border-radius: 4px'
    ].join(';');
    return [`%c${text}`, style];
  };

  return {
    log(msg) {
      console.log(...toArgs(msg));
      return createLogger();
    },
    time(template = chipTemplate) {
      const d = new Date();
      const time = [d.getHours(), d.getMinutes(), d.getSeconds()].join(':');
      const txt = `⏱ ${time}`;
      const msg = typeof template === 'function' ? template(txt) : txt;
      console.log(...toArgs(msg));
      return createLogger();
    },
    group(msg) {
      console.group(...toArgs(msg));
      return createLogger();
    },
    groupEnd() {
      console.groupEnd();
    },
    templates: {
      chip: chipTemplate,
      compose(...msgs) {
        const getTexts = msg => msg[0];
        const getStyles = ([, ...styles]) => styles;
        const text = msgs.map(getTexts).flat().join('');
        const styles = msgs.map(getStyles).flat();
        return [text, ...styles];
      },
      colorText(text, color = 'orange') {
        const style = `color: ${color};`;
        return [`%c${text}`, style];
      },
      changed(oldText, newText) {
        const newTexStylet = ['color: white'].join(';');
        const oldTextStyle = [
          'color: #7f8c8d',
          'text-decoration: line-through',
          'text-decoration-color: #95a5a6'
        ].join(';');
        return [`%c${oldText}%c ${newText}`, oldTextStyle, newTexStylet];
      },
      separator(str) {
        return [`%c${str}`, ''];
      }
    }
  };
}