// https://on.cypress.io/api

describe('H1 contains Starting message', () => {
  it('visits the app root url', () => {
    cy.visit('/')
    cy.contains('h1', 'Starting')
  })
})
