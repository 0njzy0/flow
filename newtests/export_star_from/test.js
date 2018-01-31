/*
 * @flow
 * @lint-ignore-every LINEWRAP1
 */


import {suite, test} from '../../packages/flow-dev-tools/src/test/Tester';

export default suite(({addFile, addFiles, addCode}) => [
  test('local exports override remote exports', [
    addFile('./origin.js').noNewErrors(),
    addFile('./local_override1.js').noNewErrors(),

    addCode(`
      import {C} from "./local_override1";
      (C: string);
    `).noNewErrors(),

    addCode('(C: number);').newErrors(
                             `
                               test.js:8
                                 8: (C: number);
                                     ^ Cannot cast \`C\` to number because string [1] is incompatible with number [2].
                                 References:
                                   8: (C: number);
                                       ^ [1]: string
                                   8: (C: number);
                                          ^^^^^^ [2]: number
                             `,
                           ),
  ]),

  test('local exports override remote exports regardless of export order', [
    addFile('./origin.js').noNewErrors(),
    addFile('./local_override2.js').noNewErrors(),

    addCode(`
      import {C} from "./local_override2";
      (C: string);
    `).noNewErrors(),

    addCode('(C: number);').newErrors(
                             `
                               test.js:8
                                 8: (C: number);
                                     ^ Cannot cast \`C\` to number because string [1] is incompatible with number [2].
                                 References:
                                   8: (C: number);
                                       ^ [1]: string
                                   8: (C: number);
                                          ^^^^^^ [2]: number
                             `,
                           ),
  ]),
]);
